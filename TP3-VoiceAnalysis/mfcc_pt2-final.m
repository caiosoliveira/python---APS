clear; close all; clc;

%% 1. Read audio
filename = 'tp3_pt2.wav';
[audioIn, Fs] = audioread(filename);
if size(audioIn, 2) > 1
    audioIn = audioIn(:, 1);
end
N        = length(audioIn);
duration = N / Fs;
t        = (0:N-1)' / Fs;

fprintf('File     : %s\n', filename);
fprintf('Fs       : %d Hz\n', Fs);
fprintf('Duration : %.2f s\n', duration);
fprintf('Samples  : %d\n', N);

%% 2. Short-time energy envelope
winLen_sec  = 0.030;
hopLen_sec  = 0.010;
winLen_samp = round(winLen_sec * Fs);
hopLen_samp = round(hopLen_sec * Fs);
numFrames   = floor((N - winLen_samp) / hopLen_samp) + 1;
win         = hamming(winLen_samp);

energy = zeros(numFrames, 1);
for m = 1:numFrames
    startIdx    = (m-1)*hopLen_samp + 1;
    frame       = audioIn(startIdx : startIdx+winLen_samp-1) .* win;
    energy(m)   = sum(frame .^ 2);
end
t_energy = ((0:numFrames-1)*hopLen_samp + winLen_samp/2)' / Fs;

%% 3. Spectrogram parameters
nfft     = 2^nextpow2(winLen_samp);
noverlap = winLen_samp - hopLen_samp;
[S, F, T] = spectrogram(audioIn, win, noverlap, nfft, Fs);
S_dB      = 10*log10(abs(S) + eps);

%% 4. MFCC, Delta, Delta-Delta
[coeffs, delta, deltaDelta, loc] = mfcc(audioIn, Fs);
t_mfcc = (loc + round(winLen_samp/2)) / Fs;

fprintf('\nMFCC frames      : %d\n', size(coeffs,1));
fprintf('Coefficients/frame: %d\n', size(coeffs,2));

%% 5. Tabbed figure
fig = figure('Name', 'Speech Analysis', 'NumberTitle', 'off', ...
             'Position', [50 50 1300 720]);
tg  = uitabgroup(fig);

% --- Tab 1: Waveform ---
tab1 = uitab(tg, 'Title', 'Waveform');
ax   = axes('Parent', tab1);
plot(ax, t, audioIn, 'Color', [0.1 0.3 0.7]);
xlabel(ax,'Time (s)'); ylabel(ax,'Amplitude');
title(ax,'Speech Waveform');
grid(ax,'on'); xlim(ax,[0 duration]);

% --- Tab 2: Envelope ---
tab2 = uitab(tg, 'Title', 'Envelope');
tl2  = tiledlayout(tab2, 2, 1, 'Padding','compact','TileSpacing','compact');

ax2a = nexttile(tl2);
plot(ax2a, t, audioIn, 'Color', [0.1 0.3 0.7]);
xlabel(ax2a,'Time (s)'); ylabel(ax2a,'Amplitude');
title(ax2a,'Speech Waveform');
grid(ax2a,'on'); xlim(ax2a,[0 duration]);

ax2b = nexttile(tl2);
plot(ax2b, t_energy, energy, 'Color', [0.85 0.2 0.1], 'LineWidth',1.5);
xlabel(ax2b,'Time (s)'); ylabel(ax2b,'Energy');
title(ax2b,'Short-Time Energy (30 ms Hamming, 10 ms hop)');
grid(ax2b,'on'); xlim(ax2b,[0 duration]);

% --- Tab 3: Spectrogram ---
tab3 = uitab(tg, 'Title', 'Spectrogram');
ax3  = axes('Parent', tab3);
imagesc(ax3, T, F, S_dB);
axis(ax3,'xy');
xlabel(ax3,'Time (s)'); ylabel(ax3,'Frequency (kHz)');
title(ax3,'Spectrogram (dB)');
colorbar(ax3); colormap(ax3,'jet');

% --- Tab 4: MFCC ---
% tab4 = uitab(tg, 'Title', 'MFCC');
% tl4  = tiledlayout(tab4, 3, 1, 'Padding','compact','TileSpacing','compact');
% 
% ax4a = nexttile(tl4);
% imagesc(ax4a, t_mfcc, 1:size(coeffs,2), coeffs');
% axis(ax4a,'xy');
% xlabel(ax4a,'Time (s)'); ylabel(ax4a,'Coefficient');
% title(ax4a,'MFCC (static)');
% colorbar(ax4a); colormap(ax4a,'jet');
% 
% ax4b = nexttile(tl4);
% imagesc(ax4b, t_mfcc, 1:size(delta,2), delta');
% axis(ax4b,'xy');
% xlabel(ax4b,'Time (s)'); ylabel(ax4b,'Coefficient');
% title(ax4b,'\Delta MFCC (velocity)');
% colorbar(ax4b); colormap(ax4b,'jet');
% 
% ax4c = nexttile(tl4);
% imagesc(ax4c, t_mfcc, 1:size(deltaDelta,2), deltaDelta');
% axis(ax4c,'xy');
% xlabel(ax4c,'Time (s)'); ylabel(ax4c,'Coefficient');
% title(ax4c,'\Delta\Delta MFCC (acceleration)');
% colorbar(ax4c); colormap(ax4c,'jet');
% 
% 

% % --- Tab 4 v2: MFCC (Trajetórias em Linha) ---
% tab4 = uitab(tg, 'Title', 'MFCC (Trajetórias)');
% tl4  = tiledlayout(tab4, 3, 1, 'Padding','compact','TileSpacing','compact');
% 
% % Selecionar os coeficientes a mostrar (Vamos mostrar C1, C2, C3 e C4)
% % Lembra-te que no MATLAB, coeffs(:,1) é o C0 (Energia), logo usamos 2 a 5.
% coefs_to_plot = 2:5; 
% colors = lines(length(coefs_to_plot)); % Gera cores distintas automaticamente
% 
% % --- 1. MFCC Estáticos ---
% ax4a = nexttile(tl4);
% hold(ax4a, 'on');
% for i = 1:length(coefs_to_plot)
%     % Usamos (coefs_to_plot(i)-1) no DisplayName para chamar C1, C2, C3...
%     plot(ax4a, t_mfcc, coeffs(:, coefs_to_plot(i)), 'Color', colors(i,:), ...
%         'LineWidth', 1.5, 'DisplayName', ['C' num2str(coefs_to_plot(i)-1)]);
% end
% xlabel(ax4a, 'Tempo (s)'); ylabel(ax4a, 'Amplitude do Coeficiente');
% title(ax4a, 'Trajetórias dos Primeiros Coeficientes MFCC (Forma do Trato Vocal)');
% legend(ax4a, 'Location', 'eastoutside');
% grid(ax4a, 'on'); xlim(ax4a, [0 duration]);
% 
% % --- 2. Delta MFCC ---
% ax4b = nexttile(tl4);
% hold(ax4b, 'on');
% for i = 1:length(coefs_to_plot)
%     plot(ax4b, t_mfcc, delta(:, coefs_to_plot(i)), 'Color', colors(i,:), ...
%         'LineWidth', 1.2, 'DisplayName', ['\Delta C' num2str(coefs_to_plot(i)-1)]);
% end
% xlabel(ax4b, 'Tempo (s)'); ylabel(ax4b, 'Taxa de Variação');
% title(ax4b, '\Delta MFCC (Velocidade de Articulação)');
% legend(ax4b, 'Location', 'eastoutside');
% grid(ax4b, 'on'); xlim(ax4b, [0 duration]);
% 
% % --- 3. Delta-Delta MFCC ---
% ax4c = nexttile(tl4);
% hold(ax4c, 'on');
% for i = 1:length(coefs_to_plot)
%     plot(ax4c, t_mfcc, deltaDelta(:, coefs_to_plot(i)), 'Color', colors(i,:), ...
%         'LineWidth', 1.2, 'DisplayName', ['\Delta\Delta C' num2str(coefs_to_plot(i)-1)]);
% end
% xlabel(ax4c, 'Tempo (s)'); ylabel(ax4c, 'Aceleração');
% title(ax4c, '\Delta\Delta MFCC (Aceleração de Articulação)');
% legend(ax4c, 'Location', 'eastoutside');
% grid(ax4c, 'on'); xlim(ax4c, [0 duration]);

% % --- Tab 4 v3: MFCC (Todas as Trajetórias em 2 Colunas) ---
% tab4 = uitab(tg, 'Title', 'MFCC (Trajetórias completas)');
% tl4  = tiledlayout(tab4, 3, 2, 'Padding','compact','TileSpacing','compact');
% 
% % Dividir os coeficientes (Assumindo que a coluna 1 é o C0/Energia)
% % Esquerda: C1 a C7 (índices 2 a 8) | Direita: C8 até ao fim (índices 9 a 14)
% num_cols = size(coeffs, 2);
% coefs_left = 2:min(8, num_cols);
% coefs_right = 9:num_cols;
% 
% colors_left = lines(length(coefs_left));
% colors_right = lines(length(coefs_right));
% 
% % =========================================================================
% % LINHA 1: MFCC Estáticos
% % =========================================================================
% % 1A. Esquerda (C1 - C7)
% ax4a = nexttile(tl4, 1); hold(ax4a, 'on');
% for i = 1:length(coefs_left)
%     plot(ax4a, t_mfcc, coeffs(:, coefs_left(i)), 'Color', colors_left(i,:), ...
%         'LineWidth', 1.2, 'DisplayName', ['C' num2str(coefs_left(i)-1)]);
% end
% ylabel(ax4a, 'Amplitude'); title(ax4a, 'MFCC (C1 a C7) - Forma Geral');
% legend(ax4a, 'Location', 'eastoutside'); grid(ax4a, 'on'); xlim(ax4a, [0 duration]);
% 
% % 1B. Direita (C8 - C13)
% ax4b = nexttile(tl4, 2); hold(ax4b, 'on');
% if ~isempty(coefs_right)
%     for i = 1:length(coefs_right)
%         plot(ax4b, t_mfcc, coeffs(:, coefs_right(i)), 'Color', colors_right(i,:), ...
%             'LineWidth', 1.2, 'DisplayName', ['C' num2str(coefs_right(i)-1)]);
%     end
% end
% title(ax4b, 'MFCC (C8+) - Detalhes Finos');
% legend(ax4b, 'Location', 'eastoutside'); grid(ax4b, 'on'); xlim(ax4b, [0 duration]);
% 
% % =========================================================================
% % LINHA 2: Delta MFCC (Velocidade)
% % =========================================================================
% % 2A. Esquerda (Delta C1 - C7)
% ax4c = nexttile(tl4, 3); hold(ax4c, 'on');
% for i = 1:length(coefs_left)
%     plot(ax4c, t_mfcc, delta(:, coefs_left(i)), 'Color', colors_left(i,:), ...
%         'LineWidth', 1.0, 'DisplayName', ['\Delta C' num2str(coefs_left(i)-1)]);
% end
% ylabel(ax4c, 'Taxa Variação'); title(ax4c, '\Delta MFCC (C0 - C7)');
% legend(ax4c, 'Location', 'eastoutside'); grid(ax4c, 'on'); xlim(ax4c, [0 duration]);
% 
% % 2B. Direita (Delta C8 - C13)
% ax4d = nexttile(tl4, 4); hold(ax4d, 'on');
% if ~isempty(coefs_right)
%     for i = 1:length(coefs_right)
%         plot(ax4d, t_mfcc, delta(:, coefs_right(i)), 'Color', colors_right(i,:), ...
%             'LineWidth', 1.0, 'DisplayName', ['\Delta C' num2str(coefs_right(i)-1)]);
%     end
% end
% title(ax4d, '\Delta MFCC (C8 - 13)');
% legend(ax4d, 'Location', 'eastoutside'); grid(ax4d, 'on'); xlim(ax4d, [0 duration]);
% 
% % =========================================================================
% % LINHA 3: Delta-Delta MFCC (Aceleração)
% % =========================================================================
% % 3A. Esquerda (Delta-Delta C1 - C7)
% ax4e = nexttile(tl4, 5); hold(ax4e, 'on');
% for i = 1:length(coefs_left)
%     plot(ax4e, t_mfcc, deltaDelta(:, coefs_left(i)), 'Color', colors_left(i,:), ...
%         'LineWidth', 1.0, 'DisplayName', ['\Delta\Delta C' num2str(coefs_left(i)-1)]);
% end
% xlabel(ax4e, 'Tempo (s)'); ylabel(ax4e, 'Aceleração'); title(ax4e, '\Delta\Delta MFCC (C0 - C7)');
% legend(ax4e, 'Location', 'eastoutside'); grid(ax4e, 'on'); xlim(ax4e, [0 duration]);
% 
% % 3B. Direita (Delta-Delta C8 - C13)
% ax4f = nexttile(tl4, 6); hold(ax4f, 'on');
% if ~isempty(coefs_right)
%     for i = 1:length(coefs_right)
%         plot(ax4f, t_mfcc, deltaDelta(:, coefs_right(i)), 'Color', colors_right(i,:), ...
%             'LineWidth', 1.0, 'DisplayName', ['\Delta\Delta C' num2str(coefs_right(i)-1)]);
%     end
% end
% xlabel(ax4f, 'Tempo (s)'); title(ax4f, '\Delta\Delta MFCC (C8 - 13)');
% legend(ax4f, 'Location', 'eastoutside'); grid(ax4f, 'on'); xlim(ax4f, [0 duration]);


% --- Tab 4: MFCC (Todas as Trajetórias em 2 Colunas, INCLUINDO C0) ---
tab4 = uitab(tg, 'Title', 'MFCC (Trajetórias completas)');
tl4  = tiledlayout(tab4, 3, 2, 'Padding','compact','TileSpacing','compact');

% Dividir os coeficientes
% Esquerda: C0 a C7 (índices 1 a 8) | Direita: C8 até ao fim (índices 9 a num_cols)
num_cols = size(coeffs, 2);
coefs_left = 1:min(8, num_cols); % <-- ALTERAÇÃO AQUI: Começa no índice 1 (C0)
coefs_right = 9:num_cols;

colors_left = lines(length(coefs_left));
colors_right = lines(length(coefs_right));

% =========================================================================
% LINHA 1: MFCC Estáticos
% =========================================================================
% 1A. Esquerda (C0 - C7)
ax4a = nexttile(tl4, 1); hold(ax4a, 'on');
for i = 1:length(coefs_left)
    % A lógica (coefs_left(i)-1) garante que o índice 1 se chama "C0"
    plot(ax4a, t_mfcc, coeffs(:, coefs_left(i)), 'Color', colors_left(i,:), ...
        'LineWidth', 1.2, 'DisplayName', ['C' num2str(coefs_left(i)-1)]);
end
ylabel(ax4a, 'Amplitude'); title(ax4a, 'MFCC (C0 a C7) - Energia e Forma');
legend(ax4a, 'Location', 'eastoutside'); grid(ax4a, 'on'); xlim(ax4a, [0 duration]);

% 1B. Direita (C8 - C13)
ax4b = nexttile(tl4, 2); hold(ax4b, 'on');
if ~isempty(coefs_right)
    for i = 1:length(coefs_right)
        plot(ax4b, t_mfcc, coeffs(:, coefs_right(i)), 'Color', colors_right(i,:), ...
            'LineWidth', 1.2, 'DisplayName', ['C' num2str(coefs_right(i)-1)]);
    end
end
title(ax4b, 'MFCC (C8+) - Detalhes Finos');
legend(ax4b, 'Location', 'eastoutside'); grid(ax4b, 'on'); xlim(ax4b, [0 duration]);

% =========================================================================
% LINHA 2: Delta MFCC (Velocidade)
% =========================================================================
% 2A. Esquerda (Delta C0 - C7)
ax4c = nexttile(tl4, 3); hold(ax4c, 'on');
for i = 1:length(coefs_left)
    plot(ax4c, t_mfcc, delta(:, coefs_left(i)), 'Color', colors_left(i,:), ...
        'LineWidth', 1.0, 'DisplayName', ['\Delta C' num2str(coefs_left(i)-1)]);
end
ylabel(ax4c, 'Taxa Variação'); title(ax4c, '\Delta MFCC (C0 - C7)');
legend(ax4c, 'Location', 'eastoutside'); grid(ax4c, 'on'); xlim(ax4c, [0 duration]);

% 2B. Direita (Delta C8 - C13)
ax4d = nexttile(tl4, 4); hold(ax4d, 'on');
if ~isempty(coefs_right)
    for i = 1:length(coefs_right)
        plot(ax4d, t_mfcc, delta(:, coefs_right(i)), 'Color', colors_right(i,:), ...
            'LineWidth', 1.0, 'DisplayName', ['\Delta C' num2str(coefs_right(i)-1)]);
    end
end
title(ax4d, '\Delta MFCC (C8 - 13)');
legend(ax4d, 'Location', 'eastoutside'); grid(ax4d, 'on'); xlim(ax4d, [0 duration]);

% =========================================================================
% LINHA 3: Delta-Delta MFCC (Aceleração)
% =========================================================================
% 3A. Esquerda (Delta-Delta C0 - C7)
ax4e = nexttile(tl4, 5); hold(ax4e, 'on');
for i = 1:length(coefs_left)
    plot(ax4e, t_mfcc, deltaDelta(:, coefs_left(i)), 'Color', colors_left(i,:), ...
        'LineWidth', 1.0, 'DisplayName', ['\Delta\Delta C' num2str(coefs_left(i)-1)]);
end
xlabel(ax4e, 'Tempo (s)'); ylabel(ax4e, 'Aceleração'); title(ax4e, '\Delta\Delta MFCC (C0 - C7)');
legend(ax4e, 'Location', 'eastoutside'); grid(ax4e, 'on'); xlim(ax4e, [0 duration]);

% 3B. Direita (Delta-Delta C8 - C13)
ax4f = nexttile(tl4, 6); hold(ax4f, 'on');
if ~isempty(coefs_right)
    for i = 1:length(coefs_right)
        plot(ax4f, t_mfcc, deltaDelta(:, coefs_right(i)), 'Color', colors_right(i,:), ...
            'LineWidth', 1.0, 'DisplayName', ['\Delta\Delta C' num2str(coefs_right(i)-1)]);
    end
end
xlabel(ax4f, 'Tempo (s)'); title(ax4f, '\Delta\Delta MFCC (C8 - 13)');
legend(ax4f, 'Location', 'eastoutside'); grid(ax4f, 'on'); xlim(ax4f, [0 duration]);

%% ========================================================================
%% EXTRA PARA A APRESENTAÇÃO: Comparação Energia vs Coeficiente C0 (MFCC)
%% ========================================================================

% 1. Extrair o coeficiente C0 (a primeira linha da matriz 'coeffs')
% O Matlab por defeito devolve log-energy como o primeiro elemento (index 1 no Matlab)
C0_mfcc = coeffs(:, 1); 

% 2. Normalizar ambas as curvas para facilitar a comparação visual
% Como a energia linear e a log-energia (C0) têm escalas muito diferentes,
% normalizá-las para o intervalo [0, 1] permite sobrepô-las de forma justa.
energy_norm = (energy - min(energy)) / (max(energy) - min(energy));
C0_mfcc_norm = (C0_mfcc - min(C0_mfcc)) / (max(C0_mfcc) - min(C0_mfcc));

% 3. Criar uma nova Tab para esta demonstração
tab5 = uitab(tg, 'Title', 'Energia vs C0 (MFCC)');
tl5  = tiledlayout(tab5, 2, 1, 'Padding','compact','TileSpacing','compact');

% -- Gráfico Superior: Sobreposição Normalizada --
ax5a = nexttile(tl5);
plot(ax5a, t_energy, energy_norm, 'Color', [0.85 0.2 0.1], 'LineWidth', 1.5, 'DisplayName', 'Energia Linear (Calculada)');
hold(ax5a, 'on');
% Usamos t_mfcc para o C0, pois as janelas do MFCC podem ter pequenos desvios temporais
plot(ax5a, t_mfcc, C0_mfcc_norm, '--', 'Color', [0.1 0.3 0.7], 'LineWidth', 1.5, 'DisplayName', 'C0 (Log-Energia MFCC)');
xlabel(ax5a, 'Tempo (s)');
ylabel(ax5a, 'Amplitude Normalizada [0,1]');
title(ax5a, 'Comparação: Energia Calculada vs Coeficiente C0 (Normalizados)');
legend(ax5a, 'Location', 'best');
grid(ax5a, 'on');
xlim(ax5a, [0 duration]);

% -- Gráfico Inferior: O Sinal Original (para referência visual) --
ax5b = nexttile(tl5);
plot(ax5b, t, audioIn, 'Color', [0.5 0.5 0.5]);
xlabel(ax5b, 'Tempo (s)');
ylabel(ax5b, 'Amplitude');
title(ax5b, 'Sinal de Fala Original (Referência)');
grid(ax5b, 'on');
xlim(ax5b, [0 duration]);