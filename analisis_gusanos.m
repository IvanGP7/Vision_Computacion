% Parámetros ajustables
folder_path   = 'WormImages';
output_folder = 'Resultado';

if ~exist(output_folder,'dir')
    mkdir(output_folder);
end

csv_file = fullfile(output_folder, 'recuento_gusanos.csv');
if ~isfile(csv_file)
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'nombre_fichero;muertos;vivos\n');
    fclose(fid);
end


files = dir(fullfile(folder_path,'*.tif'));
%k = 10;  % índice de la imagen a procesar
for k = 1:numel(files)
    name = files(k).name;
    I    = imread(fullfile(folder_path,name));
    
    % 1) A gris y blanqueo negros puros
    if size(I,3)==3
        gray = rgb2gray(I);
    else
        gray = I;
    end
    gray(gray==0) = 255;
    
    %% MASCARAS
    % Binarizar para obtener máscara gruesa de cristal
    MASK   = imbinarize(gray, 0.1);        % fondo claro = 1, cristal = 0
    MASK   = imcomplement(MASK);           % interior = 1
    MASK   = bwareaopen(MASK, 120);        % limpia artefactos
    
    % Aislar interior: fondo exterior a blanco
    gray2 = gray;
    gray2(~MASK) = 255;

    % Limpiar máscara preliminar (opcional)
    level  = graythresh(gray2);
    MKTemp = imbinarize(gray2, level);
    MKTemp = imcomplement(MKTemp);
    MKTemp(~MASK) = 0;
    MKFinal = bwareaopen(MKTemp, 120);
    MKFinal = bwareaopen(~MKFinal, 120);
    gray2 = gray;
    gray2(~MKFinal) = 255;  % actualizo gray2 y MASK
    MASK  = MKFinal;
    
    %% Detectar objetos oscuros con umbral adaptativo
    % 1) Prepara el gris para binarizar solo dentro de la máscara
    grayMasked = gray;
    grayMasked(~MASK) = 255;          % forzamos fuera del cristal a blanco
    T  = adaptthresh(grayMasked, 0.6, 'NeighborhoodSize', 11);
    BW0 = imbinarize(grayMasked, T);    % 1 = claro
    BW = ~BW0;                          % gusanos (oscuros) → 1
    BW(~MASK) = 0;                      % zona fuera = 0  
    
    % 4) Forzamos TODO lo que esté fuera de la máscara a 0 (negro)
    BW(~MASK) = 0;
    
    %% Eliminar Marco Mascara
    se = strel('disk',1);                        % prueba radio 3–5px
    innerMask = imerode(MASK, se);
    
    % 2) Limpiar cualquier componente que toque el borde de la imagen
    BW_noframe = imclearborder(BW);
    
    % 3) Aplicar el interior recortado para quitar resto de marco
    BW_noframe(~innerMask) = 0;
    
    %% Limpiar la imagen
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

    % Mostrar detección sobre la imagen original
    figure, imshow(gray), title('Gusanos detectados'); hold on;

    for i = 1:length(stats)
        bb = stats(i).BoundingBox;
        centroid = stats(i).Centroid;
        ecc = stats(i).Eccentricity;

        if ecc > 0.98
            rectangle('Position', bb, 'EdgeColor', 'r', 'LineWidth', 1.5);
            text(centroid(1), centroid(2), 'Muerto', 'Color', 'r', 'FontSize', 8);
            muertos = muertos + 1;
        else
            rectangle('Position', bb, 'EdgeColor', 'g', 'LineWidth', 1.5);
            text(centroid(1), centroid(2), 'Vivo', 'Color', 'g', 'FontSize', 8);
            vivos = vivos + 1;
        end
    end

    
    %% Mostrar resultados
    %figure('Name',name,'NumberTitle','off');
    %subplot(2,2,1), imshow(gray2),   title('Interior aislado');
    %subplot(2,2,2), imshow(MASK),    title('Máscara interior');
    %subplot(2,2,3), imshow(BW_noframe),    title('Máscara aplicada');
    %subplot(2,2,4), imshow(BW1),  title('Eliminar ruido');
    % (Opcional) guardar output
    % imwrite(bwDark, fullfile(output_folder, ['dark_' name]));

    %% Guardar resultados
    fid = fopen(csv_file, 'a');
    fprintf(fid, '%s;%d;%d\n', name, muertos, vivos);
    fclose(fid);

end
