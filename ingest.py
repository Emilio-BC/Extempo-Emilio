import psycopg2
from faker import Faker
import random

fake = Faker()

# Conexion a Postgres
try:
    conn = psycopg2.connect(
        host="db",
        database="hackathon",
        user="admin",
        password="password"
    )
    cur = conn.cursor()
    print("Conexion exitosa a la base de datos.")
except Exception as e:
    print("Error al conectar:", e)
    exit()

print("Generando e insertando datos de prueba...")

# Crear 5 mentores
for _ in range(5):
    cur.execute("INSERT INTO mentors (first_name, last_name, max_teams) VALUES (%s, %s, %s)",
                (fake.first_name(), fake.last_name(), random.randint(1, 3)))

# Crear 10 equipos
for i in range(10):
    cur.execute("INSERT INTO teams (team_name) VALUES (%s) RETURNING team_id", 
                (f"Team {fake.word().capitalize()}",))
    team_id = cur.fetchone()[0]
    
    # Insertar de 2 a 3 participantes por equipo para no activar el trigger de limite
    for _ in range(random.randint(2, 3)):
        cur.execute("INSERT INTO participants (first_name, last_name, team_id) VALUES (%s, %s, %s)",
                    (fake.first_name(), fake.last_name(), team_id))
    
    # Asignar un proyecto a cada equipo
    cur.execute("INSERT INTO projects (team_id, project_name, current_status) VALUES (%s, %s, 'Idea')",
                (team_id, f"Project {fake.word().capitalize()}"))

# Confirmar transaccion y cerrar
conn.commit()
cur.close()
conn.close()

print("Datos cargados con exito.")