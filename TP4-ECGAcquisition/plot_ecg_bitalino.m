%% ECG Bitalino - Multi-Lead Visualization (Chest vs. Wrist)
% -------------------------------------------------------------------------
% Loads six 3-lead ECG recordings acquired with a Bitalino + OpenSignals
% (Leads I, II, III on chest/clavicle, and Leads I, II, III on the wrist),
% converts raw ADC values to millivolts using the official Bitalino ECG
% transfer function, applies a subtle moving-average smoothing, and plots
% all six signals simultaneously in a 3 x 2 grid:
%
%       +--------------------+--------------------+
%       |  Chest  - Lead I   |  Wrist  - Lead I   |
%       +--------------------+--------------------+
%       |  Chest  - Lead II  |  Wrist  - Lead II  |
%       +--------------------+--------------------+
%       |  Chest  - Lead III |  Wrist  - Lead III |
%       +--------------------+--------------------+
%
% Folder layout expected (as in your screenshots):
%   <basePath>\torax-colect\ECG-LEAD1_YYYY-MM-DD.h5
%   <basePath>\torax-colect\ECG-LEAD2_YYYY-MM-DD.h5
%   <basePath>\torax-colect\ECG-LEAD3_YYYY-MM-DD.h5
%   <basePath>\pulso-colect\ECG-LEAD1p_YYYY-MM-DD.h5
%   <basePath>\pulso-colect\ECG-LEAD2p_YYYY-MM-DD.h5
%   <basePath>\pulso-colect\ECG-LEAD3p_YYYY-MM-DD.h5
% -------------------------------------------------------------------------

clear; clc; close all;

%% ======================== USER CONFIGURATION ============================
basePath     = 'C:\Users\Caio\Desktop\ECG bitalino';
dateStr      = '2026-04-23';     % date in file names
t_start      = 0;                % display window start [s]   <-- edit
t_end        = 4;               % display window end   [s]   <-- edit
smoothMs     = 5;                % moving-average window [ms] (subtle)
channelName  = 'channel_2';      % ECG channel (per lab PDF, slide 18)
% =========================================================================

%% Build file list (rows = Leads I/II/III, cols = Chest / Wrist)
files = { ...
  fullfile(basePath,'torax-colect',sprintf('ECG-LEAD1_%s.h5',dateStr)),  fullfile(basePath,'pulso-colect',sprintf('ECG-LEAD1p_%s.h5',dateStr));
  fullfile(basePath,'torax-colect',sprintf('ECG-LEAD2_%s.h5',dateStr)),  fullfile(basePath,'pulso-colect',sprintf('ECG-LEAD2p_%s.h5',dateStr));
  fullfile(basePath,'torax-colect',sprintf('ECG-LEAD3_%s.h5',dateStr)),  fullfile(basePath,'pulso-colect',sprintf('ECG-LEAD3p_%s.h5',dateStr)) };

titles = { ...
    'Chest - Lead I',   'Wrist - Lead I'; ...
    'Chest - Lead II',  'Wrist - Lead II'; ...
    'Chest - Lead III', 'Wrist - Lead III' };

%% Plot
figure('Name','Bitalino ECG - Chest vs. Wrist','Color','w', ...
       'Position',[80 80 1280 820]);

fs = NaN;   % keep last fs for the supertitle

for r = 1:3
    for c = 1:2
        [ecg_mV, fs] = readBitalinoECG(files{r,c}, channelName);

        % --- subtle moving-average smoothing (gold standard) ------------
        winSamples = max(3, round(smoothMs*1e-3*fs));
        ecg_s = movmean(ecg_mV, winSamples);

        % --- time axis and display window -------------------------------
        t    = (0:numel(ecg_s)-1).' / fs;
        mask = t >= t_start & t <= t_end;

        % --- plot --------------------------------------------------------
        subplot(3,2,(r-1)*2 + c);
        plot(t(mask), ecg_s(mask), 'LineWidth', 0.9);
        grid on; box on;
        xlabel('Time (s)');
        ylabel('ECG (mV)');
        title(titles{r,c});
        xlim([t_start t_end]);
    end
end

sgtitle(sprintf(['Bitalino ECG   |   Window %.2f-%.2f s   |   ' ...
                 'Moving avg = %d ms   |   fs = %g Hz'], ...
                 t_start, t_end, smoothMs, fs), 'FontWeight','bold');


%% ======================== Helper Functions ==============================
function [ecg_mV, fs] = readBitalinoECG(filePath, channelName)
% READBITALINOECG  Read one ECG channel from a Bitalino OpenSignals H5 file
% and return calibrated values in millivolts, plus the sampling rate.
%
%   Bitalino ECG transfer function (PLUX biosignals):
%         ECG(V) = ( ADC/2^n - 1/2 ) * VCC / G_ECG
%   with VCC = 3.3 V, G_ECG = 1100, n = 10 bits (channels A1-A4).

    if ~isfile(filePath)
        error('File not found:\n  %s', filePath);
    end

    info = h5info(filePath);

    % ---- Locate the device group (named after the Bitalino MAC) --------
    if isempty(info.Groups)
        error('No device group found in %s', filePath);
    end
    devGroup = info.Groups(1).Name;          % e.g. '/88:6B:0F:AB:F8:6E'
    rawPath  = [devGroup '/raw'];

    % ---- Read sampling rate from attributes ----------------------------
    fs = readAttrSafe(filePath, devGroup, ...
            {'sampling rate','sampling_rate','samplerate'});
    if isempty(fs) || ~isfinite(double(fs))
        warning('Could not read sampling rate from %s; assuming 1000 Hz.', ...
                filePath);
        fs = 1000;
    end
    fs = double(fs);

    % ---- Pick which channel_X dataset to read --------------------------
    rawInfo = h5info(filePath, rawPath);
    chNames = {rawInfo.Datasets.Name};
    chList  = chNames(startsWith(chNames,'channel_'));

    if ismember(channelName, chList)
        pick = channelName;
    elseif ~isempty(chList)
        pick = chList{1};
        warning('''%s'' not enabled in %s -- using ''%s'' instead.', ...
                channelName, filePath, pick);
    else
        error('No channel_X datasets found inside %s', rawPath);
    end

    raw = double(h5read(filePath, [rawPath '/' pick]));
    raw = raw(:);

    % ---- ECG transfer function -> millivolts ---------------------------
    VCC   = 3.3;       % V
    G_ECG = 1100;      % ECG sensor gain
    n     = 10;        % bits (A1-A4)
    ecg_V  = (raw/(2^n) - 0.5) * VCC / G_ECG;
    ecg_mV = ecg_V * 1000;
end


function val = readAttrSafe(filePath, grp, candidateNames)
% READATTRSAFE  Try several candidate attribute names and return the first
% one that exists; returns [] if none of them do.
    val = [];
    for k = 1:numel(candidateNames)
        try
            val = h5readatt(filePath, grp, candidateNames{k});
            return;
        catch
            % keep trying the next candidate
        end
    end
end
