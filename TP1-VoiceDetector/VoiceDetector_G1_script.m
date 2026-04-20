%% Pré-processamento
clear; clc; close all;

% arquivo de áudio
nome_arquivo = 'teste2_tp1_APS.wav';
[sinal_bruto, Fs] = audioread(nome_arquivo);

% aqui elimina uma coluna de som se for estereo e houver duas, mas o nosso é mono
if size(sinal_bruto, 2) > 1
    sinal_bruto = sinal_bruto(:, 1);
end

% dtrend para remoção da componente DC do sinal
sinal_sOffset = detrend(sinal_bruto);

% tempo total é o número de amostras dividido pela frequência de amostragem
N_amostras = length(sinal_sOffset);
tempo = (0:N_amostras-1) / Fs;

%plot inicial 
figure('Name', 'Plot inicial do sinal', 'NumberTitle', 'off');
subplot(2,1,1);
plot(tempo, sinal_bruto, 'r'); hold on;
plot(tempo, sinal_sOffset, 'b', 'LineWidth', 1.5);
title('Sinal de Fala - Bruto (Vermelho) vs Detrend (Azul)');
xlabel('Tempo (segundos)');
ylabel('Amplitude');
legend('Bruto', 'Sem DC Offset');
grid on;

% ==========================================
% normalização, ZCR e baseline noise

% normalização do sinal limpo (entre -1 e +1)
sinal_norm = sinal_sOffset / max(abs(sinal_sOffset));

% parâmetros da janela (20ms) e sobreposição (10ms) - já definidos no passo 2
t_janela = 0.030; 
t_sobreposicao = 0.010; 

N_janela = round(t_janela * Fs); 
N_sobreposicao = round(t_sobreposicao * Fs);
N_avanco = N_janela - N_sobreposicao; 

janela_hamming = hamming(N_janela);
num_janelas = floor((length(sinal_norm) - N_janela) / N_avanco) + 1;

% pré-alocação dos vetores
energia_rms = zeros(num_janelas, 1);
zcr = zeros(num_janelas, 1);
tempo_janelas = zeros(num_janelas, 1);

% loop de analise de short time
for i = 1:num_janelas
    indice_inicio = (i - 1) * N_avanco + 1;
    indice_fim = indice_inicio + N_janela - 1;
    
    % extrair o frame do sinal NORMALIZADO
    frame = sinal_norm(indice_inicio:indice_fim);
    
    % Aplicar a janela de Hamming para a ENERGIA (RMS)
    frame_janelado = frame .* janela_hamming;
    energia_rms(i) = sqrt(mean(frame_janelado.^2));
    
    % --- CÁLCULO DA TAXA DE PASSAGEM POR ZERO (ZCR) ---
    % Calculamos a diferença dos sinais (+1 ou -1) de amostras adjacentes.
    % Quando cruza o zero, a diferença é 2 ou -2. Pegamos o valor absoluto e dividimos por 2.
    % Nota: Não aplicamos a janela de Hamming no ZCR para não distorcer as bordas.
    mudancas_sinal = abs(sign(frame(2:end)) - sign(frame(1:end-1)));
    zcr(i) = sum(mudancas_sinal) / (2 * length(frame));
    
    tempo_janelas(i) = (indice_inicio + N_janela/2) / Fs;
end

% álculo do baseline - 300 ms
tempo_baseline = 0.300; % 300 ms
indices_baseline = find(tempo_janelas <= tempo_baseline);

% média e desvio Padrão do ruído
energia_ruido_media = mean(energia_rms(indices_baseline));
energia_ruido_std = std(energia_rms(indices_baseline));

zcr_ruido_media = mean(zcr(indices_baseline));
zcr_ruido_std = std(zcr(indices_baseline));

fprintf('--- PERFIL DO RUÍDO DE FUNDO (Primeiros 300ms) ---\n');
fprintf('Energia Média do Ruído: %f\n', energia_ruido_media);
fprintf('ZCR Médio do Ruído: %f\n\n', zcr_ruido_media);

%%« plot conjunto
figure('Name', 'Analise de Energia e ZCR', 'NumberTitle', 'off');
% sinal Normalizado
subplot(3,1,1);
plot(tempo, sinal_norm, 'Color', [0.7 0.7 0.7]); % Cinza claro
title('Sinal de Fala Normalizado');
ylabel('Amplitude');
grid on;
xlim([0 tempo(end)]);

% energia RMS com Baseline
subplot(3,1,2);
plot(tempo_janelas, energia_rms, 'k', 'LineWidth', 1.5); hold on;
% Linha mostrando a média do ruído
yline(energia_ruido_media, 'r--', 'Média Ruído', 'LabelHorizontalAlignment', 'left');
title('Energia Média Deslizante (RMS)');
ylabel('Energia');
grid on;
xlim([0 tempo(end)]);

% passagem por Zero (ZCR) com Baseline
subplot(3,1,3);
plot(tempo_janelas, zcr, 'b', 'LineWidth', 1.5); hold on;
% Linha mostrando a média do ZCR do ruído
yline(zcr_ruido_media, 'r--', 'Média ZCR Ruído', 'LabelHorizontalAlignment', 'left');
title('Taxa de Passagem por Zero (ZCR)');
ylabel('ZCR');
xlabel('Tempo (s)');
grid on;
xlim([0 tempo(end)]);


%% ==========================================
% Passo 4: Detecção com Limiares Relativos e Fine-Tuning
% ==========================================

% 1. Encontrar o pico de energia do sinal para criar limiares adaptativos
max_energia = max(energia_rms);

% 2. Parâmetros Ajustáveis (Fine-Tuning)
% Ajuste estas porcentagens para subir ou descer as linhas de corte
percentual_E_alto = 0.15;  % 8.5% da energia máxima (Pega as vogais fortes)
percentual_E_baixo = 0.02; % 2% da energia máxima (Piso mínimo para consoantes)
k_Z = 1.0;                 % Multiplicador para o ZCR do ruído

% 3. Cálculo dos Limiares Híbridos
limiar_energia_alto = percentual_E_alto * max_energia;

% O limiar baixo é o MAIOR valor entre 1% do pico OU a estatística do ruído.
% Isso impede que a linha cole no zero em salas muito silenciosas.
limiar_energia_baixo = max((energia_ruido_media + 5 * energia_ruido_std), (percentual_E_baixo * max_energia));

% O ZCR do ruído costuma ser alto e aleatório, mas as fricativas (S, X) 
% dão picos ainda maiores. O desvio padrão do ZCR costuma ser confiável.
limiar_zcr = zcr_ruido_media + k_Z * zcr_ruido_std;

% 4. Criar a máscara para as JANELAS
mascara_frames = zeros(num_janelas, 1);

for i = 1:num_janelas
    % Condição 1: Tem muita energia? É vogal.
    condicao_vogal = energia_rms(i) > limiar_energia_alto;
    
    % Condição 2: Tem pouca energia (mas acima do silêncio) E muito ZCR? É fricativa.
    condicao_fricativa = (energia_rms(i) > limiar_energia_baixo) && (zcr(i) > limiar_zcr);
    
    if condicao_vogal || condicao_fricativa
        mascara_frames(i) = 1;
    end
end

% 5. Filtros Morfológicos (O "Histerese" do Tempo)
% Agora que os limiares vão cortar a máscara, estes filtros vão brilhar!

% a. Preencher buracos (pausas oclusivas no meio de palavras, ex: o 'p' de sapo)
tempo_fechamento_s = 0.250; % 150 ms | 200
frames_fechamento = round(tempo_fechamento_s / t_sobreposicao);
mascara_frames = imclose(mascara_frames, ones(frames_fechamento, 1));

% b. Remover "cliques" e ruídos rápidos que passaram do limiar
tempo_minimo_fala_s = 0.100; % 80 ms 
frames_minimos = round(tempo_minimo_fala_s / t_sobreposicao);
mascara_frames = bwareaopen(mascara_frames, frames_minimos);

% 6. Expandir a máscara de Janelas para Amostras (Tamanho original)
mascara_amostras = zeros(N_amostras, 1);
for i = 1:num_janelas
    if mascara_frames(i) == 1
        indice_inicio = (i - 1) * N_avanco + 1;
        indice_fim = indice_inicio + N_janela - 1;
        mascara_amostras(indice_inicio:indice_fim) = 1; 
    end
end

% ==========================================
% Visualização para Fine-Tuning
% ==========================================
figure('Name', 'Fine-Tuning dos Limiares', 'NumberTitle', 'off');

% Subplot 1: Energia com Limiares
subplot(3,1,1);
plot(tempo_janelas, energia_rms, 'k', 'LineWidth', 1.2); hold on;
yline(limiar_energia_alto, 'g--', 'Limiar E Alto (Vogais)', 'LineWidth', 1.5);
yline(limiar_energia_baixo, 'r--', 'Limiar E Baixo (Base)', 'LineWidth', 1.5);
title('Ajuste de Energia');
ylabel('Energia');
grid on; xlim([0 tempo(end)]);

% Subplot 2: ZCR com Limiar
subplot(3,1,2);
plot(tempo_janelas, zcr, 'b', 'LineWidth', 1.2); hold on;
yline(limiar_zcr, 'r--', 'Limiar ZCR', 'LineWidth', 1.5);
title('Ajuste de ZCR');
ylabel('ZCR');
grid on; xlim([0 tempo(end)]);

% Subplot 3: Resultado Final
subplot(3,1,3);
plot(tempo, sinal_norm, 'Color', [0.7 0.7 0.7]); hold on;
plot(tempo, mascara_amostras * 0.8, 'r', 'LineWidth', 1.5); 
title('Máscara VAD Final');
xlabel('Tempo (s)');
ylabel('Amplitude');
grid on; xlim([0 tempo(end)]); ylim([-1 1]);