%% Configuración Inicial
clear all; close all; clc;

% Parámetros ajustables
folder_path = 'WormImages';               % Carpeta de imágenes
output_folder_bin = 'BinarizadoSuave';    % Imágenes binarias procesadas
output_folder_marcadas = 'ResultadosMarcados'; % Imágenes clasificadas
csv_filename = 'resultados_clasificacion.csv'; % Resultados en CSV

% Umbrales de segmentación
min_area = 30;                            % Área mínima (px) para considerar gusano
min_longitud = 30;                        % Longitud mínima (px)
umbral_aspect_ratio = 1.5;                % Relación largo/ancho mínima

% Umbrales de clasificación
umbral_ecc_vivo = 0.95;                   % Excentricidad máxima para vivo (más bajo = más curvado)
umbral_solid_vivo = 0.85;                 % Solidez máxima para vivo (más bajo = menos compacto)

%% Preprocesamiento y Clasificación
% Crear carpetas de salida
if ~exist(output_folder_bin, 'dir'), mkdir(output_folder_bin); end
if ~exist(output_folder_marcadas, 'dir'), mkdir(output_folder_marcadas); end

% Inicializar tabla de resultados
resultados_tabla = table(...
    'Size', [0, 4],...
    'VariableTypes', {'string', 'double', 'double', 'string'},...
    'VariableNames', {'Imagen', 'Vivos', 'Muertos', 'Clase'});

% Procesar cada imagen
image_files = dir(fullfile(folder_path, '*.tif'));
for k = 1:length(image_files)
    % Cargar y preprocesar imagen
    image_path = fullfile(folder_path, image_files(k).name);
    I = imread(image_path);
    if size(I, 3) == 3, Igray = rgb2gray(I); else, Igray = I; end
    
    % Mejora de contraste y binarización
    Ieq = adapthisteq(Igray, 'ClipLimit', 0.01); % Menos agresivo
    Ifilt = imgaussfilt(Ieq, 1.5);               % Suavizado Gaussiano
    BW = imbinarize(Ifilt, 'adaptive', 'ForegroundPolarity', 'dark', 'Sensitivity', 0.5);
    BW = imopen(BW, strel('disk', 1));           % Operaciones morfológicas suaves
    BW = imclose(BW, strel('disk', 2));
    BW = bwareaopen(BW, 10);                     % Eliminar ruido pequeño
    
    % Eliminar marco negro
    BW_negros = (BW == 0);
    BW_sin_marco_negros = imclearborder(BW_negros);
    mascara_marco = BW_negros & ~BW_sin_marco_negros;
    BW_sin_marco = BW;
    BW_sin_marco(mascara_marco) = 1;
    BW_final = bwareaopen(BW_sin_marco, 15);
    
    % Guardar imagen binaria
    [~, baseName, ~] = fileparts(image_files(k).name);
    imwrite(BW_final, fullfile(output_folder_bin, [baseName '_binaria.png']));
    
    %% Segmentación y clasificación
    BW_gusanos = ~BW_final; % Gusanos = 1 (blanco)
    stats = regionprops(BW_gusanos, 'Area', 'MajorAxisLength', 'MinorAxisLength',...
        'Eccentricity', 'Solidity', 'BoundingBox', 'PixelIdxList');
    
    num_vivos = 0;
    num_muertos = 0;
    imagen_marcada = im2uint8(cat(3, BW_final, BW_final, BW_final)); % Fondo blanco
    
    for i = 1:length(stats)
        % Filtrar por tamaño y forma
        if stats(i).Area < min_area || stats(i).MajorAxisLength < min_longitud
            continue;
        end
        
        aspect_ratio = stats(i).MajorAxisLength / stats(i).MinorAxisLength;
        if aspect_ratio < umbral_aspect_ratio
            continue;
        end
        
        % Clasificar por curvatura
        es_vivo = (stats(i).Eccentricity < umbral_ecc_vivo) && ...
                  (stats(i).Solidity < umbral_solid_vivo);
        
        % Marcar en la imagen
        contorno = bwperim(stats(i).PixelIdxList);
        [filas, cols] = ind2sub(size(BW_final), find(contorno));
        
        if es_vivo
            color = [0 255 0]; % Verde: vivo
            num_vivos = num_vivos + 1;
        else
            color = [255 0 0]; % Rojo: muerto
            num_muertos = num_muertos + 1;
        end
        
        for j = 1:length(filas)
            imagen_marcada(filas(j), cols(j), :) = color;
        end
    end
    
    % Clasificación de la imagen
    clase_imagen = 'Viva';
    if num_muertos > num_vivos, clase_imagen = 'Muerta'; end
    
    % Guardar imagen marcada
    imwrite(imagen_marcada, fullfile(output_folder_marcadas, [baseName '_marcada.png']));
    
    % Actualizar tabla de resultados
    resultados_tabla = [resultados_tabla;...
        {image_files(k).name, num_vivos, num_muertos, clase_imagen}];
    
    % Mostrar resultados en consola
    fprintf('Imagen: %s\n   - Vivos: %d | Muertos: %d | Clase: %s\n',...
        image_files(k).name, num_vivos, num_muertos, clase_imagen);
end

% Guardar CSV
writetable(resultados_tabla, csv_filename);
disp('Proceso completado. Resultados guardados en ' + csv_filename);