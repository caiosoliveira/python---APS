import json
from sentence_transformers import SentenceTransformer
import numpy as np

class ResponseEngine:
    def __init__(self, responses_path: str = "responses.json"):
        self.model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")
        with open(responses_path, encoding="utf-8") as f:
            data = json.load(f)
        self.pairs = data["pairs"]
        questions = [p["question"] for p in self.pairs]
        self.embeddings = self.model.encode(questions, convert_to_numpy=True)
        print(f"Motor carregado: {len(self.pairs)} pares de resposta.")
    def get_response(self, transcribed_text: str, threshold: float = 0.3) -> str:
        query_emb = self.model.encode([transcribed_text], convert_to_numpy=True)
        dot = np.dot(self.embeddings, query_emb.T).flatten()
        norm = np.linalg.norm(self.embeddings, axis=1) * np.linalg.norm(query_emb)
        cosine_sim = dot / norm
        best_idx = np.argmax(cosine_sim)
        best_score = cosine_sim[best_idx]
        print(f"Match: '{self.pairs[best_idx]['question']}' (score: {best_score:.2f})")
        if best_score < threshold:
            return "Desculpe, não entendi a sua questão. Pode reformular, por favor?"
        return self.pairs[best_idx]["answer"]