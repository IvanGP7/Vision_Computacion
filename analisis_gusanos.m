% Definimos la carpeta que contiene las imágenes
folder_path = 'WormImages';

% Obtenemos todos los archivos .tif dentro de esa carpeta
image_files = dir(fullfile(folder_path, '*.tif'));

% Recorremos cada imagen
for k = 1:length(image_files)
    % Construimos la ruta completa de la imagen
    image_path = fullfile(folder_path, image_files(k).name);
    
    % Leemos la imagen
    I = imread(image_path);

    % Reconvertimos a escala de grises
    if size(I, 3) == 3
        Igray = rgb2gray(I);
    else
        Igray = I;
    end

    % Mostramos el nombre de la imagen que estamos procesando
    fprintf('Procesando imagen: %s\n', image_files(k).name);

    % Mejora del contraste con ecualización adaptativa (menos agresiva)
    Ieq = adapthisteq(Igray, 'ClipLimit', 0.02);
    
    % Suavizado Gaussiano para reducir ruido (sigma pequeño)
    Ifilt = imgaussfilt(Ieq, 1);
    
    % Binarización adaptativa con mayor sensibilidad (valor más alto)
    BW = imbinarize(Ifilt, 'adaptive', 'ForegroundPolarity', 'dark', 'Sensitivity', 0.4);
    
    % Operaciones morfológicas más suaves
    BW = imopen(BW, strel('disk', 1));     % Elemento estructural más pequeño
    BW = imclose(BW, strel('disk', 1));    % Elemento estructural más pequeño
    BW = bwareaopen(BW, 50);               % Umbral más bajo para objetos pequeños
    
    % Mostrar imagen binaria resultante
    % Crear la carpeta 'BinarizadoSuave' si no existe
    output_folder = 'BinarizadoSuave';
    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
    end
    
    % Guardar la imagen binarizada
    [~, baseName, ~] = fileparts(image_files(k).name);  % Nombre sin extensión
    output_name = fullfile(output_folder, [baseName '_binaria.png']);
    imwrite(BW, output_name);
    %% Quitar marco Imagen Binarizada
    % Convertir a máscara lógica: 1 para píxeles negros (marco y gusanos), 0 para fondo blanco
    BW_negros = (BW == 0);
    
    % Eliminar objetos conectados a los bordes (esto quitará el marco, no los gusanos)
    BW_sin_marco_negros = imclearborder(BW_negros);
    
    % Obtener la máscara del marco (píxeles eliminados por imclearborder)
    mascara_marco = BW_negros & ~BW_sin_marco_negros;
    
    % Eliminar el marco de la imagen original (rellenar con blanco)
    BW_sin_marco = BW;
    BW_sin_marco(mascara_marco) = 1;
    
    % Opcional: Eliminar pequeños artefactos residuales
    BW_final = bwareaopen(BW_sin_marco, 20);  % Ajusta el umbral según necesidad
    
    %% Guardar resultados
    % Crear figura invisible
    fig = figure('Visible', 'off');
    
    % Configurar subplots
    subplot(2,2,1), imshow(I), title('Original');
    subplot(2,2,2), imshow(Igray), title('Escala de grises');
    subplot(2,2,3), imshow(BW), title('Binarizada con marco');
    subplot(2,2,4), imshow(BW_final), title('Binarizada sin marco');
    
    % Ajustar tamaño de la figura para mejor visualización
    set(fig, 'Position', [100 100 800 600]);
    
    % Guardar la figura en la carpeta "BinarizadoSuave"
    output_folder = 'BinarizadoSinMarco';
    if ~exist(output_folder, 'dir')
        mkdir(output_folder);
    end
    
    % Nombre del archivo de salida
    [~, baseName, ~] = fileparts(image_files(k).name);
    output_path = fullfile(output_folder, [baseName '_comparison.png']);
    
    % Exportar la figura como imagen (PNG)
    saveas(fig, output_path);
    
    % Cerrar la figura para liberar memoria
    close(fig);

    %% Analizar gusanos
    % Después de obtener BW_final (binaria sin marco)
    % ... (después de obtener BW_final)

    % 1. Eliminar objetos pequeños que no son gusanos (menos de 40 píxeles)
    BW_gusanos = bwareaopen(~BW_final, 40);  % Filtramos objetos <40px
    
    % 2. Segmentar solo objetos de tamaño relevante
    cc = bwconncomp(BW_gusanos);
    stats = regionprops(cc, 'Eccentricity', 'Solidity', 'Area', 'Perimeter', 'MajorAxisLength', 'MinorAxisLength');
    
    % 3. Inicializar contadores
    num_vivos = 0;
    num_muertos = 0;
    
    % 4. Clasificar cada gusano con umbrales más robustos
    for i = 1:length(stats)
        % Características
        eccentricity = stats(i).Eccentricity;  % Recto (1) vs. Curvo (0)
        aspect_ratio = stats(i).MajorAxisLength / stats(i).MinorAxisLength;  % Elongación
        
        % Reglas mejoradas (ajustar según tus imágenes)
        es_vivo = (eccentricity < 0.92) && (aspect_ratio < 8);  % Menos alargado y menos recto
        
        if es_vivo
            num_vivos = num_vivos + 1;
        else
            num_muertos = num_muertos + 1;
        end
    end
    
    % 5. Clasificación de la imagen (mayoría)
    clase_imagen = 'Viva';
    if num_muertos > num_vivos
        clase_imagen = 'Muerta';
    end
    
    % 6. Guardar resultados en un archivo (en lugar de mostrar por pantalla)
        % Mostrar resultados en pantalla
    fprintf('=============================================\n');
    fprintf('Imagen: %s\n', image_files(k).name);
    fprintf('---------------------------------------------\n');
    fprintf('Gusanos vivos detectados: %d\n', num_vivos);
    fprintf('Gusanos muertos detectados: %d\n', num_muertos);
    fprintf('Clasificación final: %s\n', clase_imagen);
    fprintf('=============================================\n\n');
    
    % Opcional: Mostrar advertencia si hay pocos gusanos
    total_gusanos = num_vivos + num_muertos;
    if total_gusanos == 0
        warning('¡Imagen sin gusanos detectados! Verifique el preprocesamiento.');
    end
    
    % ... (al final del bucle, guardar todos los resultados en un .csv)
end