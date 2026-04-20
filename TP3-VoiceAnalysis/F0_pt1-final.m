%% Pré-processamento
clear; clc; close all;

% audio_showv2.m
% F0 extraction using:
%  - Method A: Autocorrelation
%  - Method B: Autocorrelation + Center-Clipping (30% by default)
%  - Method C: Cepstrum
% Compares results with Praat-extracted F0 (text or csv with time,F0 columns).
% v2: all four signals are resampled onto a single common uniform time grid
%     (covering the overlap of both time ranges) via linear interpolation,
%     so every comparison is sample-coincident.

%% User-adjustable parameters
wavFile = 'tp3_pt1.wav';       % input audio (assumed mono). Change as needed.
praatFile = 'praat_f0.txt';      % Praat output: two columns [time(s), F0(Hz)] or csv
frameLen_ms = 30;                % frame length in ms (as required)
frameShift_ms = 15;              % frame shift in ms; default 50% overlap
centerClipRatio = 0.30;          % center-clipping threshold as fraction of frame max
minF0 = 50;                      % minimum expected F0 (Hz)
maxF0 = 500;                     % maximum expected F0 (Hz)

%% Read audio
[x, Fs] = audioread(wavFile);
if size(x,2) > 1
    x = mean(x,2); % convert to mono if necessary
end
x = x / max(abs(x)); % normalize

%% Frame parameters
frameLen  = round(Fs * frameLen_ms  / 1000);
frameShift = round(Fs * frameShift_ms / 1000);
win = hamming(frameLen); % analysis window
nFrames = floor((length(x) - frameLen) / frameShift) + 1;

% vector of frame center times (seconds)
frameTimes = ((0:(nFrames-1)) * frameShift + (frameLen/2)) / Fs;
frameTimes = frameTimes(:);

%% Preallocations
f0_ac   = zeros(nFrames,1);   % autocorrelation
f0_cl   = zeros(nFrames,1);   % autocorr + center clipping
f0_ceps = zeros(nFrames,1);   % cepstrum

%% Allowed lag range (samples)
maxLag = floor(Fs / minF0); % corresponds to min F0
minLag = ceil(Fs  / maxF0); % corresponds to max F0

%% Main frame loop
for k = 1:nFrames
    idx      = (k-1)*frameShift + (1:frameLen);
    rawFrame = x(idx);
    frame    = rawFrame .* win;

    % --- Method A: Autocorrelation ---
    ac  = xcorr(frame);
    mid = ceil(length(ac)/2);
    ac_pos = ac(mid + minLag : mid + maxLag);
    [~, relIdx] = max(ac_pos);
    lagA = minLag + (relIdx - 1);
    f0_ac(k) = Fs / lagA;

    % --- Method B: Center-clipping then autocorrelation ---
    clipTh = centerClipRatio * max(abs(rawFrame));
    cl = sign(rawFrame) .* max(abs(rawFrame) - clipTh, 0);
    if all(cl == 0)
        clipTh2 = centerClipRatio/2 * max(abs(rawFrame));
        cl = sign(rawFrame) .* max(abs(rawFrame) - clipTh2, 0);
        if all(cl == 0)
            cl = frame;
        end
    end

    ac_cl  = xcorr(cl);
    mid    = ceil(length(ac_cl)/2);
    ac_cl_pos = ac_cl(mid + minLag : mid + maxLag);
    if max(abs(ac_cl_pos)) > 0
        ac_cl_pos = ac_cl_pos / max(abs(ac_cl_pos));
    end

    [pks, locs] = findpeaks(ac_cl_pos, 'MinPeakProminence', 0.1, 'MinPeakDistance', minLag);
    if isempty(pks)
        [~, relIdx2] = max(ac_cl_pos);
        lagB = minLag + (relIdx2 - 1);
    else
        [~, best] = max(pks);
        lagB = minLag + (locs(best) - 1);
    end
    f0_cl(k) = Fs / lagB;

    % --- Method C: Cepstrum ---
    Nfft   = 2^nextpow2(frameLen*2);
    S      = fft(frame, Nfft);
    logMag = log(abs(S) + eps);
    cep    = ifft(logMag);
    qMin   = floor(Fs / maxF0);
    qMax   = ceil(Fs  / minF0);
    cep_pos = real(cep(qMin:qMax));
    [~, qidx] = max(cep_pos);
    q_peak = qMin + (qidx - 1);
    f0_ceps(k) = Fs / q_peak;
end

%% Load Praat F0 data
praatData  = load(praatFile);
praatTimes = praatData(:,1);
praatF0    = praatData(:,2);

%% Measure and correct the time lag between Praat and MATLAB via cross-correlation
% Praat uses a ~71 ms analysis window vs MATLAB's 30 ms. At transitions the
% longer window makes Praat's curve appear shifted right by ~20-30 ms.
% We detect the actual lag on a fine grid and subtract it from praatTimes.

dt_fine  = frameShift / Fs / 4;                          % 4x finer than frame step
t_fine_s = max(frameTimes(1),   praatTimes(1));
t_fine_e = min(frameTimes(end), praatTimes(end));
t_fine   = (t_fine_s : dt_fine : t_fine_e)';

praat_fine = interp1(praatTimes, praatF0, t_fine, 'linear');
ac_fine    = interp1(frameTimes, f0_ac,   t_fine, 'linear');

% xcorr(x,y) peaks at lag L when x(k) ≈ y(k-L), i.e. x lags y by L samples
maxLagSmp = round(0.15 / dt_fine);                        % search ±150 ms
[xc, lags] = xcorr(praat_fine - mean(praat_fine), ...
                    ac_fine    - mean(ac_fine), ...
                    maxLagSmp, 'normalized');
[~, peakIdx] = max(xc);
lag_time = lags(peakIdx) * dt_fine;                      % seconds Praat lags MATLAB

fprintf('Detected lag (Praat vs MATLAB): %.1f ms  →  shifting Praat time axis\n', lag_time*1000);

% Shift Praat timestamps left so both grids are temporally coincident
praatTimes_corr = praatTimes - lag_time;

%% Build a common uniform time grid over the overlapping range and interpolate
dt      = frameShift / Fs;
t_start = max(frameTimes(1),       praatTimes_corr(1));
t_end   = min(frameTimes(end),     praatTimes_corr(end));

if t_start >= t_end
    error('No temporal overlap after lag correction. Check praat_f0.txt and audio file.');
end

t_common = (t_start : dt : t_end)';

pF0_common     = interp1(praatTimes_corr, praatF0, t_common, 'linear');
f0_ac_common   = interp1(frameTimes,      f0_ac,   t_common, 'linear');
f0_cl_common   = interp1(frameTimes,      f0_cl,   t_common, 'linear');
f0_ceps_common = interp1(frameTimes,      f0_ceps, t_common, 'linear');

fprintf('Common grid: %.4f s  to  %.4f s  (%d samples, dt = %.1f ms)\n', ...
    t_common(1), t_common(end), numel(t_common), dt*1000);

%% Compute MAE — two forms

% --- Form 1: raw (no lag correction) ---
% Direct sample-to-sample comparison: Praat interpolated onto MATLAB frame
% times, no temporal shift. Reflects the full error including window-offset.
praatF0_raw = interp1(praatTimes, praatF0, frameTimes, 'linear', NaN);
validMask   = ~isnan(praatF0_raw);
pF0_raw     = praatF0_raw(validMask);
fA_raw      = f0_ac(validMask);
fB_raw      = f0_cl(validMask);
fC_raw      = f0_ceps(validMask);

mae_ac_raw   = mean(abs(pF0_raw - fA_raw));
mae_cl_raw   = mean(abs(pF0_raw - fB_raw));
mae_ceps_raw = mean(abs(pF0_raw - fC_raw));

% --- Form 2: lag-corrected (temporally aligned) ---
% After the 26.3 ms lag correction, Praat and MATLAB are on the same common
% grid. This MAE reflects only algorithmic differences, not window-offset.
mae_ac_corr   = mean(abs(pF0_common - f0_ac_common));
mae_cl_corr   = mean(abs(pF0_common - f0_cl_common));
mae_ceps_corr = mean(abs(pF0_common - f0_ceps_common));

fprintf('\n=== MAE (raw, no lag correction) ===\n');
fprintf('MAE Autocorrelation: %s\n',         num2str(mae_ac_raw));
fprintf('MAE Center-Clipped Autocorr: %s\n', num2str(mae_cl_raw));
fprintf('MAE Cepstrum: %s\n',                num2str(mae_ceps_raw));

fprintf('\n=== MAE (lag-corrected, %.1f ms shift) ===\n', lag_time*1000);
fprintf('MAE Autocorrelation: %s\n',         num2str(mae_ac_corr));
fprintf('MAE Center-Clipped Autocorr: %s\n', num2str(mae_cl_corr));
fprintf('MAE Cepstrum: %s\n',                num2str(mae_ceps_corr));


%% === Dashboard Unificado (Tabs) com Marcador de Janela

% 1. Encontrar o frame com maior energia (melhor vogal) para a demonstração
energies = zeros(nFrames, 1);
for k = 1:nFrames
    energies(k) = sum(x((k-1)*frameShift + (1:frameLen)).^2);
end
[~, k_show] = max(energies);
t_marker = frameTimes(k_show); % Tempo central da janela escolhida

% Reconstruir o sinal desse frame
idx_show = (k_show-1)*frameShift + (1:frameLen);
rawFrame_show = x(idx_show);
frame_show = rawFrame_show .* win;

% Eixos de tempo e lag em milissegundos para os gráficos
t_frame_ms = (0:frameLen-1) * 1000 / Fs; 
lag_ms_min = minLag * 1000 / Fs;
lag_ms_max = maxLag * 1000 / Fs;

% --- CRIAR FIGURA COM TABS ---
fig_main = figure('Name','Análise de F0 e Detalhe de Janela','NumberTitle','off', 'Position', [50 50 1200 800]);
tg = uitabgroup(fig_main);

% =========================================================================
% TAB 1: Comparação de F0 (Geral + Marcador)
% =========================================================================
tab1 = uitab(tg, 'Title', 'Comparação F0 (Geral)');
ax1 = axes('Parent', tab1);
plot(ax1, t_common, pF0_common,     '-k', 'LineWidth', 1.5); hold(ax1, 'on');
plot(ax1, t_common, f0_ac_common,   '-r');
plot(ax1, t_common, f0_cl_common,   '-b');
plot(ax1, t_common, f0_ceps_common, '-g');

% MARCADOR DA JANELA: Linha vertical tracejada magenta
xline(ax1, t_marker, '--m', 'LineWidth', 2, 'DisplayName', 'Janela em Análise (30ms)');

xlabel(ax1, 'Time (s)'); ylabel(ax1, 'F0 (Hz)');
legend(ax1, 'Praat interp','Autocorr','Center-Clipped','Cepstrum', 'Janela em Análise', 'Location', 'best');
title(ax1, 'Fundamental Frequency Comparison');
grid(ax1, 'on');
xlim(ax1, [t_common(1), t_common(end)]);

% =========================================================================
% TAB 2: Detalhe do Frame (30 ms) - O zoom nos métodos
% =========================================================================
tab2 = uitab(tg, 'Title', 'Detalhe do Frame (30 ms)');
tl2 = tiledlayout(tab2, 3, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

% -- met A
ac_show = xcorr(frame_show);
mid = ceil(length(ac_show)/2);
ac_pos_show = ac_show(mid:end);
lags_ms = (0:length(ac_pos_show)-1) * 1000 / Fs;

ax2a = nexttile(tl2);
plot(ax2a, t_frame_ms, frame_show, 'Color', [0.1 0.3 0.7]);
title(ax2a, '1A. Sinal Original Janelado (30 ms)');
xlabel(ax2a, 'Tempo (ms)'); ylabel(ax2a, 'Amplitude'); grid(ax2a, 'on'); xlim(ax2a, [0 30]);

ax2b = nexttile(tl2);
plot(ax2b, lags_ms, ac_pos_show, 'Color', [0.85 0.2 0.1]); hold(ax2b, 'on');
xline(ax2b, lag_ms_min, '--k', 'Lim Min'); xline(ax2b, lag_ms_max, '--k', 'Lim Max');
title(ax2b, '1B. Autocorrelação - 2ª Parte');
xlabel(ax2b, 'Lag (ms)'); ylabel(ax2b, 'Amplitude'); grid(ax2b, 'on'); xlim(ax2b, [0 30]);

% -- met B
clipTh_show = centerClipRatio * max(abs(rawFrame_show));
cl_show = sign(rawFrame_show) .* max(abs(rawFrame_show) - clipTh_show, 0);
ac_cl_show = xcorr(cl_show);
ac_cl_pos_show = ac_cl_show(mid:end);

ax2c = nexttile(tl2);
plot(ax2c, t_frame_ms, cl_show, 'Color', [0.1 0.3 0.7]);
title(ax2c, sprintf('2A. Sinal com Center-Clipping (%.0f%%)', centerClipRatio*100));
xlabel(ax2c, 'Tempo (ms)'); ylabel(ax2c, 'Amplitude'); grid(ax2c, 'on'); xlim(ax2c, [0 30]);

ax2d = nexttile(tl2);
plot(ax2d, lags_ms, ac_cl_pos_show, 'Color', [0.85 0.2 0.1]); hold(ax2d, 'on');
xline(ax2d, lag_ms_min, '--k'); xline(ax2d, lag_ms_max, '--k');
title(ax2d, '2B. Autocorrelação do Sinal Clipado');
xlabel(ax2d, 'Lag (ms)'); ylabel(ax2d, 'Amplitude'); grid(ax2d, 'on'); xlim(ax2d, [0 30]);

% -- met C
Nfft_show   = 2^nextpow2(frameLen*2);
S_show      = fft(frame_show, Nfft_show);
logMag_show = log(abs(S_show) + eps);
cep_show    = real(ifft(logMag_show));
quefrency_ms = (0:Nfft_show-1) * 1000 / Fs;

ax2e = nexttile(tl2);
plot(ax2e, quefrency_ms(1:mid), cep_show(1:mid), 'Color', [0.2 0.6 0.2]);
title(ax2e, '3A. Cepstro Real (Visão Geral)');
xlabel(ax2e, 'Quefrência (ms)'); ylabel(ax2e, 'Amplitude'); grid(ax2e, 'on'); xlim(ax2e, [0 20]);

ax2f = nexttile(tl2);
plot(ax2f, quefrency_ms, cep_show, 'Color', [0.2 0.6 0.2]); hold(ax2f, 'on');
xline(ax2f, lag_ms_min, '--k'); xline(ax2f, lag_ms_max, '--k');
title(ax2f, '3B. Cepstro Real (Zoom na Zona de Busca F0)');
xlabel(ax2f, 'Quefrência (ms)'); ylabel(ax2f, 'Amplitude'); grid(ax2f, 'on'); 
xlim(ax2f, [lag_ms_min*0.8, lag_ms_max*1.2]); 

% =========================================================================
% TAB 3: Residual (Error vs Praat) - Original Figure 2
% =========================================================================
tab3 = uitab(tg, 'Title', 'Residual (Error vs Praat)');
tl3 = tiledlayout(tab3, 4, 1, 'Padding', 'compact', 'TileSpacing', 'compact');

ax3a = nexttile(tl3);
plot(ax3a, t_common, pF0_common - f0_ac_common,   '-r');
ylabel(ax3a, 'Delta F0 (Hz)'); title(ax3a, 'F0 - Autocorr'); grid(ax3a, 'on');

ax3b = nexttile(tl3);
plot(ax3b, t_common, pF0_common - f0_cl_common,   '-b');
ylabel(ax3b, 'Delta F0 (Hz)'); title(ax3b, 'F0 - Center-Clipped'); grid(ax3b, 'on');

ax3c = nexttile(tl3);
plot(ax3c, t_common, pF0_common - f0_ceps_common, '-g');
ylabel(ax3c, 'Delta F0 (Hz)'); title(ax3c, 'F0 - Cepstrum'); grid(ax3c, 'on');

ax3d = nexttile(tl3);
plot(ax3d, praatTimes, praatF0, '-k', 'LineWidth', 1.0);
xlabel(ax3d, 'Time (s)'); ylabel(ax3d, 'F0 (Hz)'); title(ax3d, 'Praat F0 (raw .txt)'); grid(ax3d, 'on');

% Fim do script