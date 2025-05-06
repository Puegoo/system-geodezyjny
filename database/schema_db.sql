-- Tworzenie bazy danych
CREATE DATABASE pkig_system;

-- Połączenie z bazą danych
\c pkig_system

-- Włączenie rozszerzeń
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Utworzenie typów enumeracyjnych
CREATE TYPE user_status AS ENUM ('pending', 'active', 'blocked');
CREATE TYPE user_role AS ENUM ('admin', 'manager', 'employee');
CREATE TYPE leave_status AS ENUM ('pending', 'manager_approved', 'approved', 'rejected');
CREATE TYPE leave_type AS ENUM ('wypoczynkowy', 'okolicznościowy', 'zdrowotny', 'szkoleniowy', 'bezpłatny');
CREATE TYPE contract_type AS ENUM ('umowa_o_prace', 'b2b', 'umowa_zlecenie', 'umowa_o_dzielo');
CREATE TYPE transport_type AS ENUM ('uber', 'sluzbowy', 'prywatny', 'brak');
CREATE TYPE log_action AS ENUM ('create', 'read', 'update', 'delete', 'login', 'logout', 'reset_password', 'activate');

-- Tworzenie tabeli użytkowników
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255),
    role user_role NOT NULL DEFAULT 'employee',
    status user_status NOT NULL DEFAULT 'pending',
    department_id UUID,
    contract_type contract_type NOT NULL,
    has_inventory_permission BOOLEAN NOT NULL DEFAULT false,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    activated_at TIMESTAMP WITH TIME ZONE,
    blocked_until TIMESTAMP WITH TIME ZONE,
    reset_token VARCHAR(255),
    reset_token_expires_at TIMESTAMP WITH TIME ZONE
);

-- Tworzenie tabeli działów
CREATE TABLE departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    manager_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Dodanie klucza obcego dla department_id w tabeli users
ALTER TABLE users ADD CONSTRAINT fk_user_department
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL;

-- Tworzenie tabeli projektów
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    created_by UUID REFERENCES users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Tworzenie tabeli zespołów projektowych
CREATE TABLE teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    leader_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Tworzenie tabeli członków zespołu
CREATE TABLE team_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    join_date DATE NOT NULL DEFAULT CURRENT_DATE,
    leave_date DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(team_id, user_id, join_date)
);

-- Tworzenie tabeli kategorii sprzętu
CREATE TABLE equipment_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Tworzenie tabeli sprzętu
CREATE TABLE equipment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    serial_number VARCHAR(100) UNIQUE,
    production_year INTEGER,
    category_id UUID REFERENCES equipment_categories(id) ON DELETE SET NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'available',
    description TEXT,
    image_url VARCHAR(255),
    qr_code VARCHAR(255),
    added_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Tworzenie tabeli pojazdów
CREATE TABLE vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    registration_number VARCHAR(20) UNIQUE NOT NULL,
    model VARCHAR(100),
    type VARCHAR(50),
    status VARCHAR(50) NOT NULL DEFAULT 'available',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Tworzenie tabeli historii sprzętu
CREATE TABLE equipment_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL,
    user_id UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Tworzenie tabeli harmonogramu
CREATE TABLE schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    transport_type transport_type NOT NULL DEFAULT 'brak',
    vehicle_id UUID REFERENCES vehicles(id) ON DELETE SET NULL,
    created_by UUID REFERENCES users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT valid_date_range CHECK (end_date >= start_date)
);

-- Tworzenie tabeli przydziału sprzętu do harmonogramu
CREATE TABLE schedule_equipment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID REFERENCES schedules(id) ON DELETE CASCADE,
    equipment_id UUID REFERENCES equipment(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    returned_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(schedule_id, equipment_id)
);

-- Tworzenie tabeli kart pracy
CREATE TABLE timesheets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    schedule_id UUID REFERENCES schedules(id) ON DELETE CASCADE,
    work_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    transport_type transport_type NOT NULL,
    is_delegation BOOLEAN NOT NULL DEFAULT false,
    private_car_cost DECIMAL(10, 2),
    submitted_at TIMESTAMP WITH TIME ZONE,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT valid_time_range CHECK (end_time > start_time),
    CONSTRAINT valid_private_car CHECK (
        (transport_type = 'prywatny' AND private_car_cost IS NOT NULL) OR
        (transport_type != 'prywatny')
    )
);

-- Tworzenie tabeli kalkulacji płac
CREATE TABLE timesheet_calculations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    timesheet_id UUID REFERENCES timesheets(id) ON DELETE CASCADE,
    regular_hours DECIMAL(5, 2) NOT NULL DEFAULT 0,
    overtime_hours DECIMAL(5, 2) NOT NULL DEFAULT 0,
    night_hours DECIMAL(5, 2) NOT NULL DEFAULT 0,
    delegation_days INTEGER NOT NULL DEFAULT 0,
    delegation_allowance DECIMAL(10, 2) NOT NULL DEFAULT 0,
    private_car_allowance DECIMAL(10, 2) NOT NULL DEFAULT 0,
    total_gross_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Tworzenie tabeli wniosków urlopowych
CREATE TABLE leave_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    leave_type leave_type NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status leave_status NOT NULL DEFAULT 'pending',
    document_url VARCHAR(255),
    manager_id UUID REFERENCES users(id),
    manager_approved_at TIMESTAMP WITH TIME ZONE,
    admin_id UUID REFERENCES users(id),
    admin_approved_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    CONSTRAINT valid_leave_date_range CHECK (end_date >= start_date)
);

-- Tworzenie tabeli sald urlopowych
CREATE TABLE leave_balances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    leave_type leave_type NOT NULL,
    total_days INTEGER NOT NULL,
    used_days INTEGER NOT NULL DEFAULT 0,
    pending_days INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, year, leave_type)
);

-- Tworzenie tabeli podsumowań miesięcznych
CREATE TABLE monthly_summaries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    month INTEGER NOT NULL,
    total_hours DECIMAL(7, 2) NOT NULL DEFAULT 0,
    regular_hours DECIMAL(5, 2) NOT NULL DEFAULT 0,
    overtime_hours DECIMAL(5, 2) NOT NULL DEFAULT 0,
    night_hours DECIMAL(5, 2) NOT NULL DEFAULT 0,
    delegation_days INTEGER NOT NULL DEFAULT 0,
    delegation_allowance DECIMAL(10, 2) NOT NULL DEFAULT 0,
    private_car_allowance DECIMAL(10, 2) NOT NULL DEFAULT 0,
    total_gross_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    generated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, year, month)
);

-- Tworzenie tabeli logów systemowych
CREATE TABLE system_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action log_action NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id UUID,
    details JSONB,
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Tworzenie tabeli ustawień systemu
CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    setting_name VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT,
    description TEXT,
    updated_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Tworzenie tabeli przypominania o karcie pracy (piątki)
CREATE TABLE timesheet_reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    reminder_date DATE NOT NULL,
    acknowledged BOOLEAN NOT NULL DEFAULT false,
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, reminder_date)
);

-- Dodanie indeksów dla poprawy wydajności
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_department ON users(department_id);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_timesheet_user_date ON timesheets(user_id, work_date);
CREATE INDEX idx_schedules_user_date ON schedules(user_id, start_date, end_date);
CREATE INDEX idx_leave_requests_user ON leave_requests(user_id);
CREATE INDEX idx_leave_requests_status ON leave_requests(status);
CREATE INDEX idx_leave_requests_date_range ON leave_requests(start_date, end_date);
CREATE INDEX idx_team_members_user ON team_members(user_id);
CREATE INDEX idx_team_members_team ON team_members(team_id);
CREATE INDEX idx_equipment_category ON equipment(category_id);
CREATE INDEX idx_equipment_status ON equipment(status);
CREATE INDEX idx_system_logs_user ON system_logs(user_id);
CREATE INDEX idx_system_logs_created_at ON system_logs(created_at);

-- Funkcja do automatycznego aktualizacji pola updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggery aktualizujące pole updated_at przy modyfikacji rekordów
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_departments_updated_at BEFORE UPDATE ON departments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_teams_updated_at BEFORE UPDATE ON teams
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_team_members_updated_at BEFORE UPDATE ON team_members
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_equipment_updated_at BEFORE UPDATE ON equipment
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_timesheets_updated_at BEFORE UPDATE ON timesheets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_leave_requests_updated_at BEFORE UPDATE ON leave_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Funkcja do automatycznego obliczania wartości dla timesheets
CREATE OR REPLACE FUNCTION calculate_timesheet_values()
RETURNS TRIGGER AS $$
DECLARE
    hours_worked DECIMAL(5, 2);
    regular_hrs DECIMAL(5, 2);
    overtime_hrs DECIMAL(5, 2);
    night_hrs DECIMAL(5, 2);
    deleg_days INTEGER;
    deleg_allowance DECIMAL(10, 2);
    priv_car_allowance DECIMAL(10, 2);
    total_amount DECIMAL(10, 2);
    night_start TIME := '18:00:00';
    night_end TIME := '06:00:00';
    regular_rate DECIMAL(5, 2) := 1.0;
    delegation_rate DECIMAL(5, 2) := 1.3;
    overtime_rate DECIMAL(5, 2) := 1.5;
    night_rate DECIMAL(5, 2) := 1.5;
    daily_allowance DECIMAL(10, 2) := 45.0;
    car_daily_allowance DECIMAL(10, 2) := 50.0;
BEGIN
    -- Obliczanie przepracowanych godzin
    hours_worked := EXTRACT(EPOCH FROM (NEW.end_time - NEW.start_time))/3600;
    
    -- Regularne godziny (max 8)
    IF hours_worked <= 8 THEN
        regular_hrs := hours_worked;
        overtime_hrs := 0;
    ELSE
        regular_hrs := 8;
        overtime_hrs := hours_worked - 8;
    END IF;
    
    -- Obliczanie godzin nocnych
    IF NEW.start_time <= night_end AND NEW.end_time >= night_start THEN
        -- Cała zmiana w nocy
        night_hrs := hours_worked;
    ELSIF NEW.start_time >= night_start OR NEW.end_time <= night_end THEN
        -- Część zmiany w nocy
        IF NEW.start_time >= night_start THEN
            -- Początek zmiany po rozpoczęciu godzin nocnych
            night_hrs := EXTRACT(EPOCH FROM (NEW.end_time - NEW.start_time))/3600;
        ELSIF NEW.end_time <= night_end THEN
            -- Koniec zmiany przed zakończeniem godzin nocnych
            night_hrs := EXTRACT(EPOCH FROM (NEW.end_time - '00:00:00'))/3600 + 
                         EXTRACT(EPOCH FROM ('24:00:00' - NEW.start_time))/3600;
        END IF;
    ELSE
        night_hrs := 0;
    END IF;

    -- Obliczanie dni delegacji
    IF NEW.is_delegation THEN
        deleg_days := 1;
        -- Sprawdzenie długości delegacji > 1 dzień (poprzez powiązany harmonogram)
        IF EXISTS (
            SELECT 1 FROM schedules 
            WHERE id = NEW.schedule_id AND (end_date - start_date) > 0
        ) THEN
            deleg_allowance := daily_allowance;
        ELSE
            deleg_allowance := 0;
        END IF;
        
        -- Dodatek za używanie samochodu prywatnego
        IF NEW.transport_type = 'prywatny' THEN
            priv_car_allowance := COALESCE(NEW.private_car_cost, car_daily_allowance);
        ELSE
            priv_car_allowance := 0;
        END IF;
        
        -- Stawka godzinowa z dodatkiem delegacyjnym
        regular_rate := delegation_rate;
    ELSE
        deleg_days := 0;
        deleg_allowance := 0;
        priv_car_allowance := 0;
    END IF;

    -- Obliczanie całkowitej kwoty
    total_amount := (regular_hrs * regular_rate) + 
                    (overtime_hrs * overtime_rate) + 
                    (night_hrs * (night_rate - regular_rate)) + 
                    deleg_allowance + 
                    priv_car_allowance;

    -- Tworzenie lub aktualizacja rekordu kalkulacji
    IF EXISTS (SELECT 1 FROM timesheet_calculations WHERE timesheet_id = NEW.id) THEN
        UPDATE timesheet_calculations SET
            regular_hours = regular_hrs,
            overtime_hours = overtime_hrs,
            night_hours = night_hrs,
            delegation_days = deleg_days,
            delegation_allowance = deleg_allowance,
            private_car_allowance = priv_car_allowance,
            total_gross_amount = total_amount,
            updated_at = NOW()
        WHERE timesheet_id = NEW.id;
    ELSE
        INSERT INTO timesheet_calculations (
            timesheet_id, regular_hours, overtime_hours, night_hours,
            delegation_days, delegation_allowance, private_car_allowance,
            total_gross_amount
        ) VALUES (
            NEW.id, regular_hrs, overtime_hrs, night_hrs,
            deleg_days, deleg_allowance, priv_car_allowance,
            total_amount
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do automatycznych obliczeń przy zapisie karty pracy
CREATE TRIGGER calculate_timesheet_values_trigger
AFTER INSERT OR UPDATE ON timesheets
FOR EACH ROW EXECUTE FUNCTION calculate_timesheet_values();

-- Funkcja sprawdzająca konflikty urlopowe
CREATE OR REPLACE FUNCTION check_leave_conflicts()
RETURNS TRIGGER AS $$
DECLARE
    conflict_count INTEGER;
BEGIN
    -- Sprawdzenie czy istnieją konflikty z innymi zatwierdzonymi urlopami
    SELECT COUNT(*)
    INTO conflict_count
    FROM leave_requests lr
    WHERE lr.user_id = NEW.user_id
      AND lr.id != NEW.id
      AND lr.status IN ('approved', 'manager_approved')
      AND (
          (NEW.start_date BETWEEN lr.start_date AND lr.end_date) OR
          (NEW.end_date BETWEEN lr.start_date AND lr.end_date) OR
          (lr.start_date BETWEEN NEW.start_date AND NEW.end_date)
      );
      
    IF conflict_count > 0 THEN
        RAISE NOTICE 'Konflikt urlopowy wykryty dla użytkownika % w dniach % - %',
            NEW.user_id, NEW.start_date, NEW.end_date;
    END IF;
    
    -- Sprawdzenie czy istnieją konflikty z harmonogramem
    conflict_count := 0;
    
    SELECT COUNT(*)
    INTO conflict_count
    FROM schedules s
    WHERE s.user_id = NEW.user_id
      AND (
          (NEW.start_date BETWEEN s.start_date AND s.end_date) OR
          (NEW.end_date BETWEEN s.start_date AND s.end_date) OR
          (s.start_date BETWEEN NEW.start_date AND NEW.end_date)
      );
      
    IF conflict_count > 0 AND NEW.status IN ('approved', 'manager_approved') THEN
        RAISE NOTICE 'Konflikt z harmonogramem wykryty dla użytkownika % w dniach % - %',
            NEW.user_id, NEW.start_date, NEW.end_date;
    END IF;
    
    -- Aktualizacja sald urlopowych
    IF NEW.status = 'approved' THEN
        -- Jeśli urlop jest zatwierdzony, zwiększ used_days i zmniejsz pending_days
        UPDATE leave_balances
        SET used_days = used_days + (NEW.end_date - NEW.start_date + 1),
            pending_days = pending_days - (NEW.end_date - NEW.start_date + 1)
        WHERE user_id = NEW.user_id
          AND year = EXTRACT(YEAR FROM NEW.start_date)
          AND leave_type = NEW.leave_type;
    ELSIF NEW.status = 'pending' THEN
        -- Jeśli urlop jest oczekujący, zwiększ pending_days
        UPDATE leave_balances
        SET pending_days = pending_days + (NEW.end_date - NEW.start_date + 1)
        WHERE user_id = NEW.user_id
          AND year = EXTRACT(YEAR FROM NEW.start_date)
          AND leave_type = NEW.leave_type;
    ELSIF NEW.status = 'rejected' AND TG_OP = 'UPDATE' THEN
        -- Jeśli urlop jest odrzucony po aktualizacji, zmniejsz pending_days
        UPDATE leave_balances
        SET pending_days = pending_days - (NEW.end_date - NEW.start_date + 1)
        WHERE user_id = NEW.user_id
          AND year = EXTRACT(YEAR FROM NEW.start_date)
          AND leave_type = NEW.leave_type;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do sprawdzania konfliktów urlopowych
CREATE TRIGGER check_leave_conflicts_trigger
AFTER INSERT OR UPDATE ON leave_requests
FOR EACH ROW EXECUTE FUNCTION check_leave_conflicts();

-- Funkcja do generowania QR kodu dla sprzętu
CREATE OR REPLACE FUNCTION generate_equipment_qr()
RETURNS TRIGGER AS $$
BEGIN
    -- Generowanie URL QR kodu zawierającego ID sprzętu
    NEW.qr_code := 'https://pkig.pl/equipment/' || NEW.id;
    
    -- Zapisanie wpisu w historii
    INSERT INTO equipment_history (equipment_id, action, user_id, notes)
    VALUES (NEW.id, CASE WHEN TG_OP = 'INSERT' THEN 'create' ELSE 'update' END, 
            NEW.added_by, 'QR kod wygenerowany');
            
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do generowania QR kodu dla sprzętu
CREATE TRIGGER generate_equipment_qr_trigger
BEFORE INSERT OR UPDATE OF name, serial_number, category_id ON equipment
FOR EACH ROW EXECUTE FUNCTION generate_equipment_qr();

-- Funkcja do sprawdzania dostępności sprzętu przy przydzielaniu
CREATE OR REPLACE FUNCTION check_equipment_availability()
RETURNS TRIGGER AS $$
DECLARE
    is_available BOOLEAN;
BEGIN
    -- Sprawdzenie czy sprzęt jest dostępny w danym okresie
    SELECT NOT EXISTS (
        SELECT 1
        FROM schedule_equipment se
        JOIN schedules s ON se.schedule_id = s.id
        WHERE se.equipment_id = NEW.equipment_id
          AND se.id != NEW.id
          AND se.returned_at IS NULL
          AND (
              (s.start_date <= (SELECT end_date FROM schedules WHERE id = NEW.schedule_id))
              AND
              (s.end_date >= (SELECT start_date FROM schedules WHERE id = NEW.schedule_id))
          )
    ) INTO is_available;
    
    IF NOT is_available THEN
        RAISE EXCEPTION 'Sprzęt o ID % nie jest dostępny w wybranym okresie', NEW.equipment_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do sprawdzania dostępności sprzętu
CREATE TRIGGER check_equipment_availability_trigger
BEFORE INSERT OR UPDATE ON schedule_equipment
FOR EACH ROW EXECUTE FUNCTION check_equipment_availability();

-- Funkcja do automatycznego generowania piątkowych przypomnień
CREATE OR REPLACE FUNCTION generate_friday_reminders()
RETURNS TRIGGER AS $$
DECLARE
    friday_date DATE;
BEGIN
    -- Sprawdzenie czy dzisiaj jest piątek
    IF EXTRACT(DOW FROM CURRENT_DATE) = 5 THEN
        friday_date := CURRENT_DATE;
        
        -- Dodanie przypomnień dla wszystkich aktywnych użytkowników
        INSERT INTO timesheet_reminders (user_id, reminder_date)
        SELECT id, friday_date
        FROM users
        WHERE status = 'active'
          AND NOT EXISTS (
              SELECT 1 FROM timesheet_reminders
              WHERE user_id = users.id AND reminder_date = friday_date
          );
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger do generowania przypomnień uruchamiany codziennie np. przez cron job
CREATE TRIGGER generate_friday_reminders_trigger
AFTER INSERT ON system_logs
FOR EACH STATEMENT EXECUTE FUNCTION generate_friday_reminders();

-- Funkcja do aktualizacji miesięcznych podsumowań
CREATE OR REPLACE FUNCTION update_monthly_summary()
RETURNS TRIGGER AS $$
DECLARE
    year_val INTEGER;
    month_val INTEGER;
BEGIN
    year_val := EXTRACT(YEAR FROM NEW.work_date);
    month_val := EXTRACT(MONTH FROM NEW.work_date);
    
    -- Aktualizacja lub wstawienie podsumowania miesięcznego
    IF EXISTS (
        SELECT 1 FROM monthly_summaries
        WHERE user_id = NEW.user_id AND year = year_val AND month = month_val
    ) THEN
        -- Aktualizacja istniejącego podsumowania
        UPDATE monthly_summaries
        SET total_hours = (
                SELECT COALESCE(SUM(EXTRACT(EPOCH FROM (t.end_time - t.start_time))/3600), 0)
                FROM timesheets t
                WHERE t.user_id = NEW.user_id
                AND EXTRACT(YEAR FROM t.work_date) = year_val
                AND EXTRACT(MONTH FROM t.work_date) = month_val
            ),
            regular_hours = (
                SELECT COALESCE(SUM(tc.regular_hours), 0)
                FROM timesheet_calculations tc
                JOIN timesheets t ON tc.timesheet_id = t.id
                WHERE t.user_id = NEW.user_id
                AND EXTRACT(YEAR FROM t.work_date) = year_val
                AND EXTRACT(MONTH FROM t.work_date) = month_val
            ),
            overtime_hours = (
                SELECT COALESCE(SUM(tc.overtime_hours), 0)
                FROM timesheet_calculations tc
                JOIN timesheets t ON tc.timesheet_id = t.id
                WHERE t.user_id = NEW.user_id
                AND EXTRACT(YEAR FROM t.work_date) = year_val
                AND EXTRACT(MONTH FROM t.work_date) = month_val
            ),
            night_hours = (
                SELECT COALESCE(SUM(tc.night_hours), 0)
                FROM timesheet_calculations tc
                JOIN timesheets t ON tc.timesheet_id = t.id
                WHERE t.user_id = NEW.user_id
                AND EXTRACT(YEAR FROM t.work_date) = year_val
                AND EXTRACT(MONTH FROM t.work_date) = month_val
            ),
            delegation_days = (
                SELECT COALESCE(SUM(tc.delegation_days), 0)
                FROM timesheet_calculations tc
                JOIN timesheets t ON tc.timesheet_id = t.id
                WHERE t.user_id = NEW.user_id
                AND EXTRACT(YEAR FROM t.work_date) = year_val
                AND EXTRACT(MONTH FROM t.work_date) = month_val
            ),
            delegation_allowance = (
                SELECT COALESCE(SUM(tc.delegation_allowance), 0)
                FROM timesheet_calculations tc
                JOIN timesheets t ON tc.timesheet_id = t.id
                WHERE t.user_id = NEW.user_id
                AND EXTRACT(YEAR FROM t.work_date) = year_val
                AND EXTRACT(MONTH FROM t.work_date) = month_val
            ),
            private_car_allowance = (
                SELECT COALESCE(SUM(tc.private_car_allowance), 0)
                FROM timesheet_calculations tc
                JOIN timesheets t ON tc.timesheet_id = t.id
                WHERE t.user_id = NEW.user_id
                AND EXTRACT(YEAR FROM t.work_date) = year_val
                AND EXTRACT(MONTH FROM t.work_date) = month_val
            ),
            total_gross_amount = (
                SELECT COALESCE(SUM(tc.total_gross_amount), 0)
                FROM timesheet_calculations tc
                JOIN timesheets t ON tc.timesheet_id = t.id
                WHERE t.user_id = NEW.user_id
                AND EXTRACT(YEAR FROM t.work_date) = year_val
                AND EXTRACT(MONTH FROM t.work_date) = month_val
            ),
            generated_at = NOW()
        WHERE user_id = NEW.user_id AND year = year_val AND month = month_val;
    ELSE
        -- Wstawienie nowego podsumowania
        INSERT INTO monthly_summaries (
            user_id, year, month, total_hours, regular_hours, overtime_hours,
            night_hours, delegation_days, delegation_allowance, 
            private_car_allowance, total_gross_amount
        )
        SELECT 
            NEW.user_id, 
            year_val, 
            month_val,
            COALESCE(SUM(EXTRACT(EPOCH FROM (t.end_time - t.start_time))/3600), 0) as total_hours,
            COALESCE(SUM(tc.regular_hours), 0) as regular_hours,
            COALESCE(SUM(tc.overtime_hours), 0) as overtime_hours,
            COALESCE(SUM(tc.night_hours), 0) as night_hours,
            COALESCE(SUM(tc.delegation_days), 0) as delegation_days,
            COALESCE(SUM(tc.delegation_allowance), 0) as delegation_allowance,
            COALESCE(SUM(tc.private_car_allowance), 0) as private_car_allowance,
            COALESCE(SUM(tc.total_gross_amount), 0) as total_gross_amount
        FROM timesheets t
        JOIN timesheet_calculations tc ON t.id = tc.timesheet_id
        WHERE t.user_id = NEW.user_id
        AND EXTRACT(YEAR FROM t.work_date) = year_val
        AND EXTRACT(MONTH FROM t.work_date) = month_val
        GROUP BY NEW.user_id, year_val, month_val;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do aktualizacji podsumowań miesięcznych
CREATE TRIGGER update_monthly_summary_trigger
AFTER INSERT OR UPDATE ON timesheets
FOR EACH ROW EXECUTE FUNCTION update_monthly_summary();

-- Funkcja weryfikacji, czy użytkownik może być przydzielony do zadania w dniach urlopu
CREATE OR REPLACE FUNCTION check_schedule_leave_conflicts()
RETURNS TRIGGER AS $$
DECLARE
    conflict_count INTEGER;
BEGIN
    -- Sprawdzenie czy istnieje konflikt z zatwierdzonym urlopem
    SELECT COUNT(*)
    INTO conflict_count
    FROM leave_requests lr
    WHERE lr.user_id = NEW.user_id
      AND lr.status IN ('approved', 'manager_approved')
      AND (
          (NEW.start_date BETWEEN lr.start_date AND lr.end_date) OR
          (NEW.end_date BETWEEN lr.start_date AND lr.end_date) OR
          (lr.start_date BETWEEN NEW.start_date AND NEW.end_date)
      );
      
    IF conflict_count > 0 THEN
        RAISE EXCEPTION 'Nie można przydzielić pracownika do harmonogramu - konflikt z zatwierdzonym urlopem';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do sprawdzania konfliktów harmonogramu z urlopami
CREATE TRIGGER check_schedule_leave_conflicts_trigger
BEFORE INSERT OR UPDATE ON schedules
FOR EACH ROW EXECUTE FUNCTION check_schedule_leave_conflicts();

-- Funkcja do logowania działań systemowych
CREATE OR REPLACE FUNCTION log_system_action()
RETURNS TRIGGER AS $$
DECLARE
    action_type log_action;
    entity_type_val VARCHAR;
BEGIN
    -- Ustalenie typu akcji
    IF TG_OP = 'INSERT' THEN
        action_type := 'create'::log_action;
    ELSIF TG_OP = 'UPDATE' THEN
        action_type := 'update'::log_action;
    ELSIF TG_OP = 'DELETE' THEN
        action_type := 'delete'::log_action;
    END IF;
    
    -- Ustalenie typu encji
    entity_type_val := TG_TABLE_NAME;
    
    -- Logowanie działania
    IF TG_OP = 'DELETE' THEN
        INSERT INTO system_logs (user_id, action, entity_type, entity_id, details)
        VALUES (OLD.user_id, action_type, entity_type_val, OLD.id, 
                jsonb_build_object('old_data', row_to_json(OLD)));
    ELSE
        INSERT INTO system_logs (user_id, action, entity_type, entity_id, details)
        VALUES (NEW.user_id, action_type, entity_type_val, NEW.id, 
                CASE 
                    WHEN TG_OP = 'INSERT' THEN jsonb_build_object('new_data', row_to_json(NEW))
                    WHEN TG_OP = 'UPDATE' THEN jsonb_build_object(
                        'old_data', row_to_json(OLD),
                        'new_data', row_to_json(NEW)
                    )
                END);
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Triggery do logowania akcji na ważnych tabelach
CREATE TRIGGER log_timesheets_actions
AFTER INSERT OR UPDATE OR DELETE ON timesheets
FOR EACH ROW EXECUTE FUNCTION log_system_action();

CREATE TRIGGER log_leave_requests_actions
AFTER INSERT OR UPDATE OR DELETE ON leave_requests
FOR EACH ROW EXECUTE FUNCTION log_system_action();

CREATE TRIGGER log_schedules_actions
AFTER INSERT OR UPDATE OR DELETE ON schedules
FOR EACH ROW EXECUTE FUNCTION log_system_action();

-- Funkcja do obsługi logowania/wylogowania
CREATE OR REPLACE FUNCTION log_user_auth_action()
RETURNS TRIGGER AS $$
DECLARE
    action_type log_action;
BEGIN
    -- Ustalenie typu akcji
    IF NEW.last_login_at IS NOT NULL AND (OLD.last_login_at IS NULL OR NEW.last_login_at > OLD.last_login_at) THEN
        action_type := 'login'::log_action;
    ELSE
        action_type := 'update'::log_action;
    END IF;
    
    -- Logowanie działania
    INSERT INTO system_logs (user_id, action, entity_type, entity_id, details)
    VALUES (NEW.id, action_type, 'users', NEW.id, 
            jsonb_build_object(
                'old_status', OLD.status,
                'new_status', NEW.status,
                'failed_login_attempts', NEW.failed_login_attempts
            ));
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger do logowania akcji autoryzacyjnych
CREATE TRIGGER log_user_auth_actions
AFTER UPDATE OF status, last_login_at, failed_login_attempts ON users
FOR EACH ROW EXECUTE FUNCTION log_user_auth_action();

-- Funkcja do resetowania hasła
CREATE OR REPLACE FUNCTION create_password_reset_token()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.reset_token IS NOT NULL AND OLD.reset_token IS NULL THEN
        -- Ustawienie czasu wygaśnięcia tokenu (24h)
        NEW.reset_token_expires_at := NOW() + INTERVAL '24 hours';
        
        -- Logowanie akcji
        INSERT INTO system_logs (user_id, action, entity_type, entity_id, details)
        VALUES (NEW.id, 'reset_password'::log_action, 'users', NEW.id, 
                jsonb_build_object('token_expires_at', NEW.reset_token_expires_at));
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do obsługi resetowania hasła
CREATE TRIGGER create_password_reset_token_trigger
BEFORE UPDATE OF reset_token ON users
FOR EACH ROW EXECUTE FUNCTION create_password_reset_token();

-- Funkcja do inicjalizacji sald urlopowych dla nowego użytkownika
CREATE OR REPLACE FUNCTION initialize_leave_balances()
RETURNS TRIGGER AS $$
DECLARE
    current_year INTEGER;
BEGIN
    current_year := EXTRACT(YEAR FROM CURRENT_DATE);
    
    -- Dodanie początkowych sald urlopowych
    INSERT INTO leave_balances (user_id, year, leave_type, total_days)
    VALUES
        (NEW.id, current_year, 'wypoczynkowy', 
            CASE 
                WHEN NEW.contract_type = 'umowa_o_prace' THEN 26
                WHEN NEW.contract_type = 'b2b' THEN 0
                WHEN NEW.contract_type = 'umowa_zlecenie' THEN 0
                WHEN NEW.contract_type = 'umowa_o_dzielo' THEN 0
                ELSE 0
            END),
        (NEW.id, current_year, 'okolicznościowy', 
            CASE 
                WHEN NEW.contract_type = 'umowa_o_prace' THEN 4
                ELSE 0
            END),
        (NEW.id, current_year, 'zdrowotny', 
            CASE 
                WHEN NEW.contract_type = 'umowa_o_prace' THEN 4
                ELSE 0
            END),
        (NEW.id, current_year, 'szkoleniowy', 
            CASE 
                WHEN NEW.contract_type = 'umowa_o_prace' THEN 6
                WHEN NEW.contract_type = 'b2b' THEN 3
                ELSE 0
            END),
        (NEW.id, current_year, 'bezpłatny', 30);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger do inicjalizacji sald urlopowych
CREATE TRIGGER initialize_leave_balances_trigger
AFTER INSERT ON users
FOR EACH ROW EXECUTE FUNCTION initialize_leave_balances();

-- Utwórzenie domyślnych wartości dla ustawień systemu
INSERT INTO system_settings (setting_name, setting_value, description)
VALUES
    ('regular_rate', '1.0', 'Stawka podstawowa za godzinę pracy'),
    ('delegation_rate', '1.3', 'Stawka za godzinę pracy podczas delegacji'),
    ('overtime_rate', '1.5', 'Stawka za nadgodziny'),
    ('night_rate', '1.5', 'Stawka za pracę w godzinach nocnych'),
    ('night_start_time', '18:00:00', 'Początek godzin nocnych'),
    ('night_end_time', '06:00:00', 'Koniec godzin nocnych'),
    ('daily_allowance', '45.0', 'Dzienna dieta za delegację (PLN)'),
    ('car_daily_allowance', '50.0', 'Dzienny ryczałt za używanie samochodu prywatnego (PLN)'),
    ('max_failed_login_attempts', '5', 'Maksymalna liczba nieudanych prób logowania przed blokadą konta'),
    ('account_block_duration', '30 minutes', 'Czas blokady konta po przekroczeniu limitu nieudanych logowań'),
    ('password_reset_token_validity', '24 hours', 'Czas ważności tokenu do resetowania hasła');

-- Utworzenie kategorii sprzętu
INSERT INTO equipment_categories (name, description)
VALUES
    ('Tachimetry', 'Elektroniczne urządzenia pomiarowe do pomiarów kątów i odległości'),
    ('GPS', 'Odbiorniki GPS do precyzyjnego pozycjonowania'),
    ('Lasery', 'Urządzenia laserowe do pomiarów'),
    ('Drony', 'Bezzałogowe statki powietrzne do fotogrametrii'),
    ('Akcesoria', 'Statywy, lustra, baterie i inne akcesoria'),
    ('Komputery', 'Laptopy, tablety i komputery stacjonarne'),
    ('Inny sprzęt', 'Pozostały sprzęt i narzędzia');

-- Utworzenie konta administratora systemowego
INSERT INTO departments (name)
VALUES ('Administracja');

INSERT INTO users (
    first_name, 
    last_name, 
    email, 
    password_hash, 
    role, 
    status, 
    department_id,
    contract_type,
    has_inventory_permission,
    activated_at
)
VALUES (
    'Admin', 
    'Systemowy', 
    'admin@pkig.pl', 
    crypt('admin123', gen_salt('bf')), 
    'admin', 
    'active', 
    (SELECT id FROM departments WHERE name = 'Administracja'),
    'umowa_o_prace',
    true,
    NOW()
);

-- Funkcja do zapobiegania usunięciu konta admin@pkig.pl
CREATE OR REPLACE FUNCTION prevent_admin_deletion()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.email = 'admin@pkig.pl' THEN
        RAISE EXCEPTION 'Nie można usunąć konta głównego administratora';
    END IF;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Trigger do ochrony konta administratora
CREATE TRIGGER prevent_admin_deletion_trigger
BEFORE DELETE ON users
FOR EACH ROW EXECUTE FUNCTION prevent_admin_deletion();

-- Aktulizacja relacji kierownika działu
UPDATE departments 
SET manager_id = (SELECT id FROM users WHERE email = 'admin@pkig.pl') 
WHERE name = 'Administracja';

-- Utwórzenie kluczy obcych, które nie mogły być utworzone wcześniej ze względu na relacje cykliczne
ALTER TABLE projects 
ADD CONSTRAINT fk_project_creator 
FOREIGN KEY (created_by) REFERENCES users(id);

-- Funkcja do aktualizacji sald urlopowych na początku roku
CREATE OR REPLACE FUNCTION initialize_yearly_leave_balances()
RETURNS void AS $$
DECLARE
    new_year INTEGER;
BEGIN
    new_year := EXTRACT(YEAR FROM CURRENT_DATE);
    
    -- Dodanie sald urlopowych na nowy rok dla wszystkich aktywnych użytkowników
    INSERT INTO leave_balances (user_id, year, leave_type, total_days)
    SELECT 
        u.id, 
        new_year, 
        lt.leave_type,
        CASE 
            WHEN lt.leave_type = 'wypoczynkowy' AND u.contract_type = 'umowa_o_prace' THEN 26
            WHEN lt.leave_type = 'okolicznościowy' AND u.contract_type = 'umowa_o_prace' THEN 4
            WHEN lt.leave_type = 'zdrowotny' AND u.contract_type = 'umowa_o_prace' THEN 4
            WHEN lt.leave_type = 'szkoleniowy' AND u.contract_type = 'umowa_o_prace' THEN 6
            WHEN lt.leave_type = 'szkoleniowy' AND u.contract_type = 'b2b' THEN 3
            WHEN lt.leave_type = 'bezpłatny' THEN 30
            ELSE 0
        END AS total_days
    FROM 
        users u
    CROSS JOIN (
        SELECT unnest(enum_range(NULL::leave_type)) AS leave_type
    ) lt
    WHERE 
        u.status = 'active'
        AND NOT EXISTS (
            SELECT 1 FROM leave_balances lb
            WHERE lb.user_id = u.id 
              AND lb.year = new_year
              AND lb.leave_type = lt.leave_type
        );
END;
$$ LANGUAGE plpgsql;

-- Dodatkowe indeksy poprawiające wydajność
CREATE INDEX idx_projects_dates ON projects(start_date, end_date);
CREATE INDEX idx_timesheets_work_date ON timesheets(work_date);
CREATE INDEX idx_monthly_summaries_year_month ON monthly_summaries(year, month);
CREATE INDEX idx_leave_balances_year ON leave_balances(year);
CREATE INDEX idx_equipment_serial_number ON equipment(serial_number);
CREATE INDEX idx_vehicles_registration ON vehicles(registration_number);
CREATE INDEX idx_system_logs_action ON system_logs(action);

-- Komentarze do tabel
COMMENT ON TABLE users IS 'Tabela przechowująca dane użytkowników systemu';
COMMENT ON TABLE departments IS 'Tabela przechowująca strukturę działów firmy';
COMMENT ON TABLE projects IS 'Tabela przechowująca dane projektów';
COMMENT ON TABLE teams IS 'Tabela przechowująca dane zespołów projektowych';
COMMENT ON TABLE team_members IS 'Tabela łącząca użytkowników z zespołami';
COMMENT ON TABLE equipment_categories IS 'Tabela kategorii sprzętu';
COMMENT ON TABLE equipment IS 'Tabela sprzętu firmowego';
COMMENT ON TABLE vehicles IS 'Tabela pojazdów firmowych';
COMMENT ON TABLE equipment_history IS 'Tabela historii zmian sprzętu';
COMMENT ON TABLE schedules IS 'Tabela harmonogramów pracy';
COMMENT ON TABLE schedule_equipment IS 'Tabela przydziału sprzętu do harmonogramów';
COMMENT ON TABLE timesheets IS 'Tabela kart pracy';
COMMENT ON TABLE timesheet_calculations IS 'Tabela obliczeń dla kart pracy';
COMMENT ON TABLE leave_requests IS 'Tabela wniosków urlopowych';
COMMENT ON TABLE leave_balances IS 'Tabela sald urlopowych';
COMMENT ON TABLE monthly_summaries IS 'Tabela miesięcznych podsumowań pracy';
COMMENT ON TABLE system_logs IS 'Tabela logów systemowych';
COMMENT ON TABLE system_settings IS 'Tabela ustawień systemowych';
COMMENT ON TABLE timesheet_reminders IS 'Tabela przypomnień o wypełnianiu kart pracy';

-- Widok do szybkiego przeglądu użytkowników i ich działów
CREATE VIEW vw_users_departments AS
SELECT 
    u.id,
    u.first_name,
    u.last_name,
    u.email,
    u.role,
    u.status,
    d.name AS department_name,
    u.contract_type,
    u.has_inventory_permission,
    u.created_at,
    u.activated_at
FROM
    users u
LEFT JOIN
    departments d ON u.department_id = d.id;

-- Widok do analizy czasu pracy
CREATE VIEW vw_work_time_analysis AS
SELECT 
    u.id AS user_id,
    u.first_name,
    u.last_name,
    d.name AS department_name,
    t.work_date,
    EXTRACT(YEAR FROM t.work_date) AS year,
    EXTRACT(MONTH FROM t.work_date) AS month,
    EXTRACT(EPOCH FROM (t.end_time - t.start_time))/3600 AS hours_worked,
    tc.regular_hours,
    tc.overtime_hours,
    tc.night_hours,
    t.is_delegation,
    tc.delegation_allowance,
    tc.private_car_allowance,
    tc.total_gross_amount,
    p.name AS project_name
FROM 
    timesheets t
JOIN 
    users u ON t.user_id = u.id
LEFT JOIN 
    departments d ON u.department_id = d.id
JOIN 
    timesheet_calculations tc ON t.id = tc.timesheet_id
LEFT JOIN 
    schedules s ON t.schedule_id = s.id
LEFT JOIN 
    projects p ON s.project_id = p.id;

-- Widok do analizy urlopów
CREATE VIEW vw_leave_analysis AS
SELECT 
    u.id AS user_id,
    u.first_name,
    u.last_name,
    d.name AS department_name,
    lr.leave_type,
    lr.start_date,
    lr.end_date,
    (lr.end_date - lr.start_date + 1) AS days_count,
    lr.status,
    EXTRACT(YEAR FROM lr.start_date) AS year,
    EXTRACT(MONTH FROM lr.start_date) AS start_month,
    lb.total_days,
    lb.used_days,
    lb.pending_days,
    (lb.total_days - lb.used_days - lb.pending_days) AS available_days
FROM 
    leave_requests lr
JOIN 
    users u ON lr.user_id = u.id
LEFT JOIN 
    departments d ON u.department_id = d.id
JOIN 
    leave_balances lb ON u.id = lb.user_id 
                      AND EXTRACT(YEAR FROM lr.start_date) = lb.year 
                      AND lr.leave_type = lb.leave_type;

-- Widok do inwentaryzacji
CREATE VIEW vw_inventory AS
SELECT 
    e.id,
    e.name,
    e.serial_number,
    e.production_year,
    ec.name AS category_name,
    e.status,
    e.qr_code,
    u.first_name || ' ' || u.last_name AS added_by_user,
    e.created_at,
    e.updated_at,
    (
        SELECT COUNT(*)
        FROM schedule_equipment se
        JOIN schedules s ON se.schedule_id = s.id
        WHERE se.equipment_id = e.id
          AND se.returned_at IS NULL
          AND s.start_date <= CURRENT_DATE
          AND s.end_date >= CURRENT_DATE
    ) > 0 AS is_currently_assigned
FROM 
    equipment e
JOIN 
    equipment_categories ec ON e.category_id = ec.id
LEFT JOIN 
    users u ON e.added_by = u.id;

-- Widok do harmonogramu tygodniowego
CREATE VIEW vw_weekly_schedule AS
SELECT 
    s.id,
    s.start_date,
    s.end_date,
    u.id AS user_id,
    u.first_name,
    u.last_name,
    p.name AS project_name,
    t.name AS team_name,
    leader.first_name || ' ' || leader.last_name AS team_leader,
    s.transport_type,
    CASE 
        WHEN s.vehicle_id IS NOT NULL THEN v.registration_number
        ELSE NULL
    END AS vehicle,
    (
        SELECT string_agg(eq.name, ', ')
        FROM schedule_equipment se
        JOIN equipment eq ON se.equipment_id = eq.id
        WHERE se.schedule_id = s.id
    ) AS assigned_equipment
FROM 
    schedules s
JOIN 
    users u ON s.user_id = u.id
LEFT JOIN 
    projects p ON s.project_id = p.id
LEFT JOIN 
    teams t ON s.team_id = t.id
LEFT JOIN 
    users leader ON t.leader_id = leader.id
LEFT JOIN 
    vehicles v ON s.vehicle_id = v.id
WHERE 
    s.start_date <= CURRENT_DATE + INTERVAL '7 days'
    AND s.end_date >= CURRENT_DATE - INTERVAL '7 days';

-- Końcowe potwierdzenie utworzenia schematu
SELECT 'Schemat bazy danych PKIG został pomyślnie utworzony.' AS result;