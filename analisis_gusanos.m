% Parámetros ajustables
folder_path   = 'WormImages';
output_folder = 'Resultado';
image_output_folder = fullfile(output_folder, 'Imagenes');
ground_truth_file = fullfile('WormDataA.csv');
csv_file = fullfile(output_folder, 'Resultados.csv');

if exist(output_folder,'dir')
    rmdir(output_folder, 's');
end
    mkdir(output_folder);
    mkdir(image_output_folder);
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Nombre_fichero;Status;Muertos;Vivos\n');
    fclose(fid);

% Estructurar datos reales
if isfile(ground_truth_file)
    % Leer archivo como texto y reemplazar comas por punto y coma
    raw1 = fileread(ground_truth_file);
    raw1 = strrep(raw1, ',', ';');

    % Escribir a archivo temporal limpio
    fid = fopen(ground_truth_file, 'w');
    fwrite(fid, raw1);
    fclose(fid);
end

files = dir(fullfile(folder_path,'*.tif'));
%k = 1;  % índice de la imagen a procesar
for k = 1:numel(files)
    name = files(k).name;
    I    = imread(fullfile(folder_path,name));
    
    %% MASCARAS
    % Binarizar para obtener máscara gruesa de cristal
    MASK   = imbinarize(I, 0.1);        % fondo claro = 1, cristal = 0
    MASK   = imcomplement(MASK);           % interior = 1
    MASK   = bwareaopen(MASK, 120);        % Eliminar regiones
    
    % Aislar interior: fondo exterior a blanco
    interior = I;
    interior(~MASK) = 255;

    % Segunda binarización de la máscara
    level  = graythresh(interior);
    MKTemp = imbinarize(interior, level);   % umbral de Otsu
    MKTemp = imcomplement(MKTemp);
    MKTemp(~MASK) = 0;
    MKFinal = bwareaopen(MKTemp, 120);      % elimina regiones pequeñas
    MKFinal = bwareaopen(~MKFinal, 120);    % elimina huecos pequeños
    MASK  = MKFinal;
    
    %% Detectar objetos oscuros con umbral adaptativo
    % Prepara la imagen para binarizar solo dentro de la máscara
    grayMasked = I;
    grayMasked(~MASK) = 255;          % forzamos fuera del cristal a blanco
    T  = adaptthresh(grayMasked, 0.6, 'NeighborhoodSize', 11);
    BW0 = imbinarize(grayMasked, T);    % 1 = claro
    BW = ~BW0;                          % gusanos (oscuros) → 1
    BW(~MASK) = 0;                      % zona fuera = 0  
    
    % Forzamos TODO lo que esté fuera de la máscara a 0 (negro)
    BW(~MASK) = 0;
    
    %% Eliminar Marco Mascara
    se = strel('disk',1);                        % prueba radio 3–5px
    innerMask = imerode(MASK, se);
    % Limpiar cualquier componente que toque el borde de la imagen
    BW_noframe = imclearborder(BW);
    % Aplicar el interior recortado para quitar resto de marco
    BW_noframe(~innerMask) = 0;
    
    %% Filtrado morfológico
    BW1 = bwareaopen(BW_noframe, 150);
    se = strel('disk', 1);  % disco pequeño para suavizado ligero
    BW1 = imopen(BW1, se); % Eliminar bordes
    BW1 = bwareaopen(BW1, 150); % Eliminar Bloques
    BW1 = imfill(BW1, 'holes'); % Cerrar huecos
    BW1 = bwareaopen(BW1, 250); % Eliminar Bloques
    BW1 = imopen(BW1, se); % Eliminar bordes
    BW1 = imclose(BW1, strel('disk', 1));

    %% Detección Gusanos


    vivos = 0;
    muertos = 0;

    stats = regionprops(BW1, 'BoundingBox', 'Eccentricity', 'Centroid');
    L = bwlabel(BW1);

    % Mostrar y guardar imagen con anotaciones
    fig = figure('Visible', 'off');
    imshow(I), title('Gusanos detectados'); hold on;

    for i = 1:length(stats)
        bb = stats(i).BoundingBox;
        centroid = stats(i).Centroid;
        ecc = stats(i).Eccentricity;

        if ecc > 0.99
            rectangle('Position', bb, 'EdgeColor', 'r', 'LineWidth', 1.5);
            text(centroid(1), centroid(2), 'Muerto', 'Color', 'r', 'FontSize', 8);
            muertos = muertos + 1;
        else
            rectangle('Position', bb, 'EdgeColor', 'g', 'LineWidth', 1.5);
            text(centroid(1), centroid(2), 'Vivo', 'Color', 'g', 'FontSize', 8);
            vivos = vivos + 1;
        end
    end

    if muertos < vivos
        status = "alive";
    else 
        status = "dead";
    end
    saveas(fig, fullfile(image_output_folder, [name(1:end-4) '_detect.png']));
    close(fig);

    %% Guardar resultados
    %figure('Name',name,'NumberTitle','off');
    %subplot(2,2,1), imshow(interior),   title('Interior aislado');
    %subplot(2,2,2), imshow(MASK),    title('Máscara interior');
    %subplot(2,2,3), imshow(BW_noframe),    title('Máscara aplicada');
    %subplot(2,2,4), imshow(BW1),  title('Eliminar residuos y distinción de gusanos');
    fid = fopen(csv_file, 'a');
    fprintf(fid, '%s;%s;%d;%d\n', name, status, muertos, vivos);
    fclose(fid);
    
end

%% Contador de porcentaje sobre el numero de aciertos
T1 = readtable(ground_truth_file);
T2 = readtable(csv_file);

% Comparar columna 'Status' (segunda columna)
status1 = strtrim(string(T1{:,2}));
status2 = strtrim(string(T2{:,2}));

coinciden = strcmpi(status1, status2);
porcentaje = 100 * sum(coinciden) / numel(coinciden);
fprintf('Coincidencia en la columna "Status": %.2f%%\n', porcentaje);