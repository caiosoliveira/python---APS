%% VoiceDetector_G2.m
%  Melhorias em relação ao G1:
%    [M1] Mínimo Deslizante substitui o baseline fixo de 300ms
%    [M2] Limiares em escala de SNR (dB) — agnósticos à intensidade absoluta
%    [M3] Estimação Recursiva com alpha_d adaptativo (voz vs silêncio)

%% ==========================================
%  Pré-processamento  (idêntico ao G1)
% ==========================================
clear; clc; close all;

nome_arquivo = 'teste2_tp1_APS.wav';
[sinal_bruto, Fs] = audioread(nome_arquivo);

if size(sinal_bruto, 2) > 1
    sinal_bruto = sinal_bruto(:, 1);
end

sinal_sOffset = detrend(sinal_bruto);

N_amostras = length(sinal_sOffset);
tempo = (0:N_amostras-1) / Fs;

figure('Name', 'Plot inicial do sinal', 'NumberTitle', 'off');
subplot(2,1,1);
plot(tempo, sinal_bruto, 'r'); hold on;
plot(tempo, sinal_sOffset, 'b', 'LineWidth', 1.5);
title('Sinal de Fala - Bruto (Vermelho) vs Detrend (Azul)');
xlabel('Tempo (segundos)');
ylabel('Amplitude');
legend('Bruto', 'Sem DC Offset');
grid on;

%% ==========================================
%  Normalização, janelamento e cálculo de RMS / ZCR  (idêntico ao G1)
% ==========================================

sinal_norm = sinal_sOffset / max(abs(sinal_sOffset));

t_janela       = 0.020;
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

    frame            = sinal_norm(indice_inicio:indice_fim);
    frame_janelado   = frame .* janela_hamming;
    energia_rms(i)   = sqrt(mean(frame_janelado.^2));

    mudancas_sinal   = abs(sign(frame(2:end)) - sign(frame(1:end-1)));
    zcr(i)           = sum(mudancas_sinal) / (2 * length(frame));

    tempo_janelas(i) = (indice_inicio + N_janela/2) / Fs;
end

%% ==========================================
%  [M1] Mínimo Deslizante (Sliding Minimum Statistics)
%
%  Ideia central: em qualquer janela de ~1s de áudio quase sempre existe
%  pelo menos um frame de silêncio. O mínimo da energia suavizada nessa
%  janela causal (só olha para o passado) é uma boa estimativa do ruído
%  de fundo *naquele instante*, sem depender de um trecho inicial fixo.
%
%  Equação:
%    E_suav(t) = α_s · E_suav(t-1) + (1-α_s) · E(t)      [suavização]
%    λ_min(t)  = β · min{ E_suav(τ) : t-W ≤ τ ≤ t }      [mínimo causal]
%
%  β > 1 corrige o viés de subestimação introduzido pelo mínimo.
% ==========================================

t_janela_min  = 1.0;   % lookback de 1 segundo
W_min         = round(t_janela_min / t_sobreposicao);  % em frames
beta_correcao = 1.5;   % fator de correção do mínimo
alpha_smooth  = 0.85;  % suavização da energia antes de tirar o mínimo

energia_suavizada    = zeros(num_janelas, 1);
energia_suavizada(1) = energia_rms(1);
for i = 2:num_janelas
    energia_suavizada(i) = alpha_smooth * energia_suavizada(i-1) + ...
                           (1 - alpha_smooth) * energia_rms(i);
end

lambda_min = zeros(num_janelas, 1);
for i = 1:num_janelas
    idx_inicio_janela = max(1, i - W_min + 1);
    lambda_min(i)     = min(energia_suavizada(idx_inicio_janela:i)) * beta_correcao;
end

lambda_min = max(lambda_min, 1e-10);  % proteger contra divisão por zero

%% ==========================================
%  [M3] Estimação Recursiva com alpha_d Adaptativo
%
%  A estimativa recursiva do ruído segue:
%    λ_rec(t) = α_d · λ_rec(t-1) + (1-α_d) · E(t)
%
%  O segredo é o alpha_d variável:
%    · α_d alto (≈ 0.98) → memória longa → durante VOZ, a estimativa
%      quase não se move; a voz não "contamina" o perfil do ruído.
%    · α_d baixo (≈ 0.85) → adaptação rápida → durante SILÊNCIO, a
%      estimativa acompanha mudanças reais no ruído de fundo.
%
%  Para decidir qual α_d usar em cada frame, calculamos um SNR provisório
%  usando a estimativa do frame anterior (bootstrap com λ_min).
%
%  Âncora: λ_rec nunca ultrapassa 3× λ_min para evitar que períodos
%  longos de fala "inflem" a estimativa indefinidamente.
% ==========================================

alpha_voz      = 0.98;  % adaptação lenta durante voz
alpha_silencio = 0.85;  % adaptação rápida durante silêncio
snr_limiar_bootstrap_dB = 3.0;  % limiar provisório de bootstrap (dB)

lambda_rec    = zeros(num_janelas, 1);
lambda_rec(1) = lambda_min(1);  % inicializa com o mínimo deslizante

for i = 2:num_janelas
    % SNR provisório com base na estimativa do frame anterior
    snr_provisorio = 10 * log10(energia_rms(i) / max(lambda_rec(i-1), 1e-10));

    if snr_provisorio < snr_limiar_bootstrap_dB
        alpha_d = alpha_silencio;  % provável silêncio → atualiza rápido
    else
        alpha_d = alpha_voz;       % provável voz     → atualiza devagar
    end

    lambda_rec(i) = alpha_d * lambda_rec(i-1) + (1 - alpha_d) * energia_rms(i);

    % Âncora: impede que a estimativa derive para cima durante fala longa
    lambda_rec(i) = min(lambda_rec(i), lambda_min(i) * 3.0);
    lambda_rec(i) = max(lambda_rec(i), 1e-10);
end

%% ==========================================
%  [M2] Limiares em Escala de SNR (dB)
%
%  SNR_dB(t) = 10 · log₁₀( E(t) / λ_rec(t) )
%
%  Os limiares θ_alto e θ_baixo são definidos em dB acima do ruído local.
%  Isso torna a decisão independente da intensidade absoluta da voz:
%  um sussurro a 6 dB acima do ruído é tratado igual a uma vogal forte
%  a 6 dB acima do ruído — o que faz sentido fisicamente.
%
%  Limiares típicos de referência:
%    θ_alto  ≈ 6 dB  → detecção segura (vogais, sons vozeados)
%    θ_baixo ≈ 1.5 dB → piso para fricativas (acima do ruído, mas fraco)
% ==========================================

snr_db      = 10 * log10(energia_rms ./ lambda_rec);

theta_alto  = 10;   % dB — detecção segura (vogais, vozeados)
theta_baixo = 3.0;   % dB — piso para fricativas
k_Z         = 1.8;   % multiplicador do ZCR (igual ao G1)

% Limiar ZCR: calculado sobre os frames onde SNR < 2 dB (silêncio provável)
% Em vez do baseline fixo de 300ms, usamos os frames dinamicamente silenciosos.
indices_silencio = find(snr_db < 2.0);
if length(indices_silencio) < 5
    % Fallback: se quase não há silêncio, usa os primeiros 300ms
    indices_silencio = find(tempo_janelas <= 0.300);
    fprintf('[AVISO] Poucos frames silenciosos detectados. Usando fallback 300ms para ZCR.\n');
end
zcr_ruido_media = mean(zcr(indices_silencio));
zcr_ruido_std   = std(zcr(indices_silencio));
limiar_zcr      = zcr_ruido_media + k_Z * zcr_ruido_std;

fprintf('--- PERFIL DO RUÍDO ADAPTATIVO (G2) ---\n');
fprintf('λ_rec inicial (frame 1):              %f\n', lambda_rec(1));
fprintf('λ_rec final   (frame N):              %f\n', lambda_rec(end));
fprintf('ZCR médio do ruído (frames silenc.):  %f\n', zcr_ruido_media);
fprintf('Limiar SNR Alto:   %.1f dB\n', theta_alto);
fprintf('Limiar SNR Baixo:  %.1f dB\n', theta_baixo);
fprintf('Limiar ZCR:        %.4f\n\n', limiar_zcr);

%% ==========================================
%  Visualização: Energia com Estimativas de Ruído Adaptativas
% ==========================================
figure('Name', 'Análise Adaptativa de Energia e ZCR (G2)', 'NumberTitle', 'off');

subplot(3,1,1);
plot(tempo, sinal_norm, 'Color', [0.7 0.7 0.7]);
title('Sinal de Fala Normalizado');
ylabel('Amplitude');
grid on; xlim([0 tempo(end)]);

subplot(3,1,2);
plot(tempo_janelas, energia_rms, 'k',   'LineWidth', 1.2); hold on;
plot(tempo_janelas, lambda_min,  'b--', 'LineWidth', 1.2);
plot(tempo_janelas, lambda_rec,  'r-',  'LineWidth', 1.8);
title('Energia RMS com Estimativas Adaptativas de Ruído');
ylabel('Energia');
legend('Energia RMS', 'Mínimo Deslizante (λ_{min})', 'Estimativa Recursiva (λ_{rec})', ...
       'Location', 'northeast');
grid on; xlim([0 tempo(end)]);

subplot(3,1,3);
plot(tempo_janelas, zcr, 'b', 'LineWidth', 1.5); hold on;
yline(limiar_zcr, 'r--', 'Limiar ZCR', 'LabelHorizontalAlignment', 'left', 'LineWidth', 1.2);
title('Taxa de Passagem por Zero (ZCR)');
ylabel('ZCR'); xlabel('Tempo (s)');
grid on; xlim([0 tempo(end)]);

%% ==========================================
%  Detecção VAD com limiares em SNR dB  (estrutura idêntica ao G1)
% ==========================================

mascara_frames = zeros(num_janelas, 1);

for i = 1:num_janelas
    % Condição 1: SNR alto → vogal / som vozeado forte
    condicao_vogal     = snr_db(i) > theta_alto;

    % Condição 2: SNR acima do piso E ZCR alto → fricativa (s, x, f...)
    condicao_fricativa = (snr_db(i) > theta_baixo) && (zcr(i) > limiar_zcr);

    if condicao_vogal || condicao_fricativa
        mascara_frames(i) = 1;
    end
end

% --- Filtros Morfológicos (idênticos ao G1) ---

% a. Preencher buracos (pausas oclusivas: o 'p' de "sapo", o 't' de "ato")
tempo_fechamento_s = 0.100;
frames_fechamento  = round(tempo_fechamento_s / t_sobreposicao);
mascara_frames     = imclose(mascara_frames, ones(frames_fechamento, 1));

% b. Remover eventos rápidos (cliques, ruídos impulsivos)
tempo_minimo_fala_s = 0.080;
frames_minimos      = round(tempo_minimo_fala_s / t_sobreposicao);
mascara_frames      = bwareaopen(mascara_frames, frames_minimos);

% --- Expandir máscara para o domínio de amostras ---
mascara_amostras = zeros(N_amostras, 1);
for i = 1:num_janelas
    if mascara_frames(i) == 1
        indice_inicio = (i - 1) * N_avanco + 1;
        indice_fim    = min(indice_inicio + N_janela - 1, N_amostras);
        mascara_amostras(indice_inicio:indice_fim) = 1;
    end
end

%% ==========================================
%  Visualização: Fine-Tuning em dB de SNR (G2)
% ==========================================
figure('Name', 'Fine-Tuning dos Limiares em SNR dB (G2)', 'NumberTitle', 'off');

subplot(3,1,1);
plot(tempo_janelas, snr_db, 'k', 'LineWidth', 1.2); hold on;
yline(theta_alto,  'g--', sprintf('θ alto = %.0f dB (Vogais)',    theta_alto),  'LineWidth', 1.5);
yline(theta_baixo, 'r--', sprintf('θ baixo = %.1f dB (Fricativas)', theta_baixo), 'LineWidth', 1.5);
yline(0, 'b:', 'SNR = 0 dB  (nível do ruído)', 'LineWidth', 1.0);
title('SNR por Frame — Limiares em dB (G2)');
ylabel('SNR (dB)');
grid on; xlim([0 tempo(end)]);

subplot(3,1,2);
plot(tempo_janelas, zcr, 'b', 'LineWidth', 1.2); hold on;
yline(limiar_zcr, 'r--', 'Limiar ZCR', 'LineWidth', 1.5);
title('Ajuste de ZCR');
ylabel('ZCR');
grid on; xlim([0 tempo(end)]);

subplot(3,1,3);
plot(tempo, sinal_norm, 'Color', [0.7 0.7 0.7]); hold on;
plot(tempo, mascara_amostras * 0.8, 'r', 'LineWidth', 1.5);
title('Máscara VAD Final (G2)');
xlabel('Tempo (s)'); ylabel('Amplitude');
grid on; xlim([0 tempo(end)]); ylim([-1 1]);