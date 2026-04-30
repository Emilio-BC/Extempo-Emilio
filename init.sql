CREATE TABLE teams (
    team_id SERIAL PRIMARY KEY,
    team_name VARCHAR(100) NOT NULL
);

CREATE TABLE participants (
    participant_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    team_id INT REFERENCES teams(team_id)
);

CREATE TABLE mentors (
    mentor_id SERIAL PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    max_teams INT NOT NULL
);

CREATE TABLE team_mentors (
    team_id INT REFERENCES teams(team_id),
    mentor_id INT REFERENCES mentors(mentor_id),
    PRIMARY KEY (team_id, mentor_id)
);

CREATE TABLE projects (
    project_id SERIAL PRIMARY KEY,
    team_id INT REFERENCES teams(team_id),
    project_name VARCHAR(100) NOT NULL,
    current_status VARCHAR(50) DEFAULT 'Idea'
);

CREATE TABLE project_status_history (
    history_id SERIAL PRIMARY KEY,
    project_id INT REFERENCES projects(project_id),
    status VARCHAR(50) NOT NULL,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE evaluations (
    evaluation_id SERIAL PRIMARY KEY,
    judge_id INT,
    team_id INT REFERENCES teams(team_id),
    score DECIMAL(5,2)
);

-- Controlar el tope de miembros por equipo
CREATE OR REPLACE FUNCTION check_team_limit()
RETURNS TRIGGER AS $$
DECLARE
    current_members INT;
BEGIN
    SELECT COUNT(*) INTO current_members FROM participants WHERE team_id = NEW.team_id;
    IF current_members >= 4 THEN
        RAISE EXCEPTION 'El equipo ya tiene el cupo lleno';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_team_limit
BEFORE INSERT ON participants
FOR EACH ROW EXECUTE FUNCTION check_team_limit();

-- Controlar el tope de equipos por mentor
CREATE OR REPLACE FUNCTION check_mentor_capacity()
RETURNS TRIGGER AS $$
DECLARE
    current_teams INT;
    max_allowed INT;
BEGIN
    SELECT COUNT(*) INTO current_teams FROM team_mentors WHERE mentor_id = NEW.mentor_id;
    SELECT max_teams INTO max_allowed FROM mentors WHERE mentor_id = NEW.mentor_id;
    
    IF current_teams >= max_allowed THEN
        RAISE EXCEPTION 'Este mentor no puede tomar mas equipos';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_mentor_capacity
BEFORE INSERT ON team_mentors
FOR EACH ROW EXECUTE FUNCTION check_mentor_capacity();

-- Registrar el historial de estados del proyecto
CREATE OR REPLACE FUNCTION log_project_status()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.current_status IS DISTINCT FROM NEW.current_status THEN
        INSERT INTO project_status_history (project_id, status)
        VALUES (NEW.project_id, NEW.current_status);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER track_project_status
AFTER UPDATE ON projects
FOR EACH ROW EXECUTE FUNCTION log_project_status();

-- Procedure para mandar un puntaje
CREATE OR REPLACE PROCEDURE SubmitEvaluation(p_judge_id INT, p_team_id INT, p_score DECIMAL)
LANGUAGE plpgsql
AS $$
DECLARE
    proj_status VARCHAR(50);
BEGIN
    SELECT current_status INTO proj_status 
    FROM projects 
    WHERE team_id = p_team_id;

    IF proj_status != 'Delivered' THEN
        ROLLBACK;
        RAISE EXCEPTION 'El proyecto no se ha entregado';
    END IF;

    INSERT INTO evaluations (judge_id, team_id, score)
    VALUES (p_judge_id, p_team_id, p_score);
    
    COMMIT;
END;
$$;

