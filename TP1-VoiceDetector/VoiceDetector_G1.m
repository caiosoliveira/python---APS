function mascara_amostras = VoiceDetector_G1(nome_arquivo)
% VoiceDetector_G1 - Detecção de Atividade de Voz (VAD) por energia RMS e ZCR
%
% Entrada:
%   nome_arquivo  - caminho para o arquivo de áudio .wav
%
% Saída:
%   mascara_amostras - vetor binário (0/1) com mesma duração do sinal,
%                      onde 1 indica presença de voz detectada

%% Pré-processamento
[sinal_bruto, Fs] = audioread(nome_arquivo);

% Garante sinal mono
if size(sinal_bruto, 2) > 1
    sinal_bruto = sinal_bruto(:, 1);
end

% Remoção da componente DC
sinal_sOffset = detrend(sinal_bruto);

N_amostras = length(sinal_sOffset);
tempo = (0:N_amostras-1) / Fs;

% Normalização para [-1, 1]
sinal_norm = sinal_sOffset / max(abs(sinal_sOffset));

%% Análise de curto prazo (Short-Time Analysis)
% Janela de 20ms com sobreposição de 10ms
t_janela       = 0.030;
t_sobreposicao = 0.010;

N_janela      = round(t_janela * Fs);
N_sobreposicao = round(t_sobreposicao * Fs);
N_avanco      = N_janela - N_sobreposicao;

janela_hamming = hamming(N_janela);
num_janelas    = floor((length(sinal_norm) - N_janela) / N_avanco) + 1;

energia_rms  = zeros(num_janelas, 1);
zcr          = zeros(num_janelas, 1);
tempo_janelas = zeros(num_janelas, 1);

for i = 1:num_janelas
    indice_inicio = (i - 1) * N_avanco + 1;
    indice_fim    = indice_inicio + N_janela - 1;
    frame         = sinal_norm(indice_inicio:indice_fim);

    % Energia RMS com janela de Hamming
    frame_janelado = frame .* janela_hamming;
    energia_rms(i) = sqrt(mean(frame_janelado.^2));

    % ZCR sem janelamento para preservar as bordas
    mudancas_sinal = abs(sign(frame(2:end)) - sign(frame(1:end-1)));
    zcr(i) = sum(mudancas_sinal) / (2 * length(frame));

    tempo_janelas(i) = (indice_inicio + N_janela/2) / Fs;
end

%% Estimativa do ruído de fundo (primeiros 300ms)
indices_baseline = find(tempo_janelas <= 0.300);

energia_ruido_media = mean(energia_rms(indices_baseline));
energia_ruido_std   = std(energia_rms(indices_baseline));
zcr_ruido_media     = mean(zcr(indices_baseline));
zcr_ruido_std       = std(zcr(indices_baseline));

fprintf('--- Perfil do Ruído de Fundo (300ms) ---\n');
fprintf('Energia Média: %f\n', energia_ruido_media);
fprintf('ZCR Médio:     %f\n\n', zcr_ruido_media);

%% Limiares adaptativos (relativos ao pico e ao ruído estimado)
max_energia = max(energia_rms);

percentual_E_alto  = 0.12;
percentual_E_baixo = 0.02;
k_Z = 1.0;

limiar_energia_alto  = percentual_E_alto * max_energia;
limiar_energia_baixo = max((energia_ruido_media + 5 * energia_ruido_std),(percentual_E_baixo * max_energia));
limiar_zcr           = zcr_ruido_media + k_Z * zcr_ruido_std;

%% Decisão por frame: vogais (alta energia) e fricativas (baixa energia + alto ZCR)
mascara_frames = zeros(num_janelas, 1);

for i = 1:num_janelas
    condicao_vogal    = energia_rms(i) > limiar_energia_alto;
    condicao_fricativa = (energia_rms(i) > limiar_energia_baixo) && (zcr(i) > limiar_zcr);

    if condicao_vogal || condicao_fricativa
        mascara_frames(i) = 1;
    end
end

%% Filtros morfológicos para suavização temporal da máscara

% Fechamento: preenche pausas internas (ex: oclusivas)
frames_fechamento = round(0.250 / t_sobreposicao);
mascara_frames = imclose(mascara_frames, ones(frames_fechamento, 1));

% Abertura: remove ativações espúrias muito curtas
frames_minimos = round(0.100 / t_sobreposicao);
mascara_frames = bwareaopen(mascara_frames, frames_minimos);

%% Expansão da máscara para resolução de amostras
mascara_amostras = zeros(N_amostras, 1);
for i = 1:num_janelas
    if mascara_frames(i) == 1
        indice_inicio = (i - 1) * N_avanco + 1;
        indice_fim    = indice_inicio + N_janela - 1;
        mascara_amostras(indice_inicio:indice_fim) = 1;
    end
end

%% Visualizações

figure('Name', 'Sinal Bruto vs Detrend', 'NumberTitle', 'off');
subplot(2,1,1);
plot(tempo, sinal_bruto, 'r'); hold on;
plot(tempo, sinal_sOffset, 'b', 'LineWidth', 1.5);
title('Sinal Bruto (Vermelho) vs Detrend (Azul)');
xlabel('Tempo (s)'); ylabel('Amplitude');
legend('Bruto', 'Sem DC Offset'); grid on;

figure('Name', 'Energia RMS e ZCR', 'NumberTitle', 'off');
subplot(3,1,1);
plot(tempo, sinal_norm, 'Color', [0.7 0.7 0.7]);
title('Sinal Normalizado'); ylabel('Amplitude'); grid on; xlim([0 tempo(end)]);

subplot(3,1,2);
plot(tempo_janelas, energia_rms, 'k', 'LineWidth', 1.5); hold on;
yline(energia_ruido_media, 'r--', 'Média Ruído', 'LabelHorizontalAlignment', 'left');
title('Energia RMS'); ylabel('Energia'); grid on; xlim([0 tempo(end)]);

subplot(3,1,3);
plot(tempo_janelas, zcr, 'b', 'LineWidth', 1.5); hold on;
yline(zcr_ruido_media, 'r--', 'Média ZCR Ruído', 'LabelHorizontalAlignment', 'left');
title('ZCR'); ylabel('ZCR'); xlabel('Tempo (s)'); grid on; xlim([0 tempo(end)]);

figure('Name', 'Fine-Tuning dos Limiares', 'NumberTitle', 'off');
subplot(3,1,1);
plot(tempo_janelas, energia_rms, 'k', 'LineWidth', 1.2); hold on;
yline(limiar_energia_alto,  'g--', 'Limiar E Alto (Vogais)', 'LineWidth', 1.5);
yline(limiar_energia_baixo, 'r--', 'Limiar E Baixo (Base)',  'LineWidth', 1.5);
title('Limiares de Energia'); ylabel('Energia'); grid on; xlim([0 tempo(end)]);

subplot(3,1,2);
plot(tempo_janelas, zcr, 'b', 'LineWidth', 1.2); hold on;
yline(limiar_zcr, 'r--', 'Limiar ZCR', 'LineWidth', 1.5);
title('Limiar ZCR'); ylabel('ZCR'); grid on; xlim([0 tempo(end)]);

subplot(3,1,3);
plot(tempo, sinal_norm, 'Color', [0.7 0.7 0.7]); hold on;
plot(tempo, mascara_amostras * 0.8, 'r', 'LineWidth', 1.5);
title('Máscara VAD Final'); xlabel('Tempo (s)'); ylabel('Amplitude');
grid on; xlim([0 tempo(end)]); ylim([-1 1]);

end