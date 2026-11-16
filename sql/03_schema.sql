-- =====================================================
-- 03_schema.sql  (AP project: MediOS)
-- The 7 final tables from dbms/01_normalization.md (3NF / BCNF),
-- written for PostgreSQL.
--
-- How to run (on an empty database):
--   psql -d <database> -f dbms/03_schema.sql
--
-- NOTE: Prisma will create its own tables from schema.prisma.
-- This file is the plain SQL version, so the design can be read
-- and checked without Prisma. Names and keys are the same.
-- =====================================================

-- Drop in reverse order (children first) so the file can be run again
DROP TABLE IF EXISTS invoice_items CASCADE;
DROP TABLE IF EXISTS invoices      CASCADE;
DROP TABLE IF EXISTS appointments  CASCADE;
DROP TABLE IF EXISTS services      CASCADE;
DROP TABLE IF EXISTS doctors       CASCADE;
DROP TABLE IF EXISTS departments   CASCADE;
DROP TABLE IF EXISTS patients      CASCADE;


-- 1. patients: registration data.
-- email is UNIQUE because a patient is found by email.
CREATE TABLE patients (
    patient_id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name    VARCHAR(50)  NOT NULL,
    last_name     VARCHAR(50)  NOT NULL,
    phone         VARCHAR(15)  NOT NULL,
    email         VARCHAR(100) NOT NULL UNIQUE,
    date_of_birth DATE         NOT NULL,
    gender        VARCHAR(6)   NOT NULL,
    CONSTRAINT ck_patient_phone  CHECK (phone ~ '^\+?[0-9]{10,14}$'),
    CONSTRAINT ck_patient_email  CHECK (email LIKE '%_@_%._%'),
    CONSTRAINT ck_patient_dob    CHECK (date_of_birth <= CURRENT_DATE),   -- cannot be born in the future
    CONSTRAINT ck_patient_gender CHECK (gender IN ('MALE','FEMALE','OTHER'))
);


-- 2. departments: Cardiology, Neurology, ...
CREATE TABLE departments (
    department_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    department_name VARCHAR(80) NOT NULL UNIQUE
);


-- 3. doctors: each doctor belongs to exactly one department.
-- RESTRICT: a department with doctors cannot be deleted.
CREATE TABLE doctors (
    doctor_id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    doctor_name    VARCHAR(100) NOT NULL,
    specialization VARCHAR(80)  NOT NULL,
    department_id  INTEGER      NOT NULL REFERENCES departments(department_id) ON DELETE RESTRICT
);


-- 4. services: the price list (consultation, ECG, blood test, ...).
-- list_price is the price today. Old invoices keep their own charged_price.
CREATE TABLE services (
    service_code VARCHAR(10)   PRIMARY KEY,
    service_name VARCHAR(100)  NOT NULL UNIQUE,
    list_price   NUMERIC(10,2) NOT NULL,
    CONSTRAINT ck_service_price CHECK (list_price >= 0)
);


-- 5. appointments: scheduling. One patient with one doctor at one time.
-- RESTRICT on both links: medical history must not disappear by deleting a patient or doctor.
-- UNIQUE (doctor_id, appointment_date, start_time) stops double booking of a doctor.
CREATE TABLE appointments (
    appointment_id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_date DATE        NOT NULL,
    start_time       TIME        NOT NULL,
    status           VARCHAR(10) NOT NULL DEFAULT 'SCHEDULED',
    patient_id       INTEGER     NOT NULL REFERENCES patients(patient_id) ON DELETE RESTRICT,
    doctor_id        INTEGER     NOT NULL REFERENCES doctors(doctor_id)   ON DELETE RESTRICT,
    CONSTRAINT uq_doctor_slot    UNIQUE (doctor_id, appointment_date, start_time),
    CONSTRAINT ck_appt_status    CHECK (status IN ('SCHEDULED','COMPLETED','CANCELLED','NO_SHOW'))
);


-- 6. invoices: one invoice for each appointment (appointment_id is UNIQUE).
-- payment_method is NULL until the invoice is paid.
CREATE TABLE invoices (
    invoice_no     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    appointment_id INTEGER     NOT NULL UNIQUE REFERENCES appointments(appointment_id) ON DELETE RESTRICT,
    invoice_date   DATE        NOT NULL DEFAULT CURRENT_DATE,
    payment_status VARCHAR(10) NOT NULL DEFAULT 'PENDING',
    payment_method VARCHAR(10),
    CONSTRAINT ck_payment_status CHECK (payment_status IN ('PENDING','PAID','REFUNDED')),
    CONSTRAINT ck_payment_method CHECK (payment_method IS NULL OR payment_method IN ('CASH','CARD','UPI','INSURANCE')),
    CONSTRAINT ck_paid_has_method CHECK (payment_status <> 'PAID' OR payment_method IS NOT NULL)   -- a paid invoice must say how
);


-- 7. invoice_items: the services on an invoice (many-to-many between invoices and services).
-- CASCADE: if an invoice is deleted, its lines go with it.
-- charged_price is the price at the time of billing (it can differ from services.list_price later).
CREATE TABLE invoice_items (
    invoice_no    INTEGER       NOT NULL REFERENCES invoices(invoice_no)   ON DELETE CASCADE,
    service_code  VARCHAR(10)   NOT NULL REFERENCES services(service_code) ON DELETE RESTRICT,
    quantity      SMALLINT      NOT NULL DEFAULT 1,
    charged_price NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (invoice_no, service_code),
    CONSTRAINT ck_item_qty   CHECK (quantity > 0),
    CONSTRAINT ck_item_price CHECK (charged_price >= 0)
);
