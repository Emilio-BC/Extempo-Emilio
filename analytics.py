import duckdb
import pandas as pd
import random
from sqlalchemy import create_engine, text

engine = create_engine('postgresql://admin:password@db:5432/hackathon')

with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as conn:
    teams_df = pd.read_sql("SELECT team_id FROM teams", conn)
    mentors_df = pd.read_sql("SELECT mentor_id FROM mentors", conn)
    
    for team_id in teams_df['team_id']:
        try:
            conn.execute(text(f"INSERT INTO team_mentors (team_id, mentor_id) VALUES ({team_id}, {random.choice(mentors_df['mentor_id'])}) ON CONFLICT DO NOTHING"))
        except:
            pass
        
        conn.execute(text(f"UPDATE projects SET current_status = 'Approved' WHERE team_id = {team_id}"))
        conn.execute(text(f"UPDATE projects SET current_status = 'Delivered' WHERE team_id = {team_id}"))
        
        score = round(random.uniform(70.0, 100.0), 2)
        conn.execute(text(f"CALL SubmitEvaluation(1, {team_id}, {score})"))

print("Consultando con DuckDB...")

df_mentors = pd.read_sql("SELECT * FROM mentors", engine)
df_team_mentors = pd.read_sql("SELECT * FROM team_mentors", engine)
df_evals = pd.read_sql("SELECT * FROM evaluations", engine)
df_history = pd.read_sql("SELECT * FROM project_status_history", engine)
df_teams = pd.read_sql("SELECT * FROM teams", engine)
df_participants = pd.read_sql("SELECT * FROM participants", engine)

query_mentores = """
SELECT m.first_name, m.last_name, AVG(e.score) as score_promedio
FROM df_mentors m
JOIN df_team_mentors tm ON m.mentor_id = tm.mentor_id
JOIN df_evals e ON tm.team_id = e.team_id
GROUP BY m.first_name, m.last_name
ORDER BY score_promedio DESC
LIMIT 3
"""
duckdb.query(query_mentores).to_df().to_parquet('top_mentores.parquet')

query_tiempos = """
SELECT AVG(d.changed_at - a.changed_at) as tiempo_promedio
FROM df_history a
JOIN df_history d ON a.project_id = d.project_id
WHERE a.status = 'Approved' AND d.status = 'Delivered'
"""
duckdb.query(query_tiempos).to_df().to_parquet('cuello_botella.parquet')

query_participantes = """
SELECT t.team_name, COUNT(p.participant_id) as total_participantes
FROM df_teams t
JOIN df_participants p ON t.team_id = p.team_id
GROUP BY t.team_name
"""
duckdb.query(query_participantes).to_df().to_parquet('distribucion.parquet')

print("Archivos Parquet listos.")

