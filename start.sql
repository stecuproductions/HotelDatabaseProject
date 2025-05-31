DROP TABLE reservation_services CASCADE CONSTRAINTS;
DROP TABLE payments CASCADE CONSTRAINTS;
DROP TABLE reservations CASCADE CONSTRAINTS;
DROP TABLE rooms CASCADE CONSTRAINTS;
DROP TABLE guests CASCADE CONSTRAINTS;
DROP TABLE services CASCADE CONSTRAINTS;

CREATE TABLE guests (
    id_guest NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name VARCHAR2(255),
    last_name VARCHAR2(255),
    phone VARCHAR2(20),
    email VARCHAR2(255)
);

CREATE TABLE rooms (
    id_room         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    room_number     VARCHAR2(20),
    room_type       VARCHAR2(20)
                    CHECK (room_type IN ('single','double','triple','quadruple')),
    price_per_night NUMBER(10,2),
    is_available    CHAR(1) DEFAULT 'Y'
                    CHECK (is_available IN ('Y', 'N'))
);

CREATE TABLE reservations (
    id_reservation NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_guest NUMBER NOT NULL,
    id_room NUMBER NOT NULL,
    start_date DATE,
    end_date DATE,
    total_price NUMBER(10, 2),
    status VARCHAR2(20) DEFAULT 'Awaiting' 
           CHECK (status IN ('Awaiting', 'Active', 'Finished', 'Cancelled')),
    CONSTRAINT fk_reservations_guest FOREIGN KEY (id_guest)
        REFERENCES guests(id_guest) ON DELETE CASCADE,
    CONSTRAINT fk_reservations_room FOREIGN KEY (id_room)
        REFERENCES rooms(id_room)
);

CREATE TABLE services (
    id_service NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    service_name VARCHAR2(255),
    service_price NUMBER(10, 2)
);

CREATE TABLE reservation_services (
    id_reservation_service NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_reservation NUMBER NOT NULL,
    id_service NUMBER NOT NULL,
    CONSTRAINT fk_reservation_services_reservation FOREIGN KEY (id_reservation)
        REFERENCES reservations(id_reservation) ON DELETE CASCADE,
    CONSTRAINT fk_reservation_services_service FOREIGN KEY (id_service)
        REFERENCES services(id_service)
);

CREATE TABLE payments (
    id_payment NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_reservation NUMBER NOT NULL,
    payment_date DATE,
    amount NUMBER(10, 2),
    payment_method VARCHAR2(50),
    CONSTRAINT fk_payments_reservation FOREIGN KEY (id_reservation)
        REFERENCES reservations(id_reservation) ON DELETE CASCADE
);

-- INSERTS

INSERT INTO guests (first_name, last_name, phone, email) VALUES 
('Jan', 'Kowalski', '123456789', 'jan.kowalski@example.com'),
('Anna', 'Nowak', '987654321', 'anna.nowak@example.com'),
('Piotr', 'Zieliński', '555666777', 'piotr.z@example.com'),
('Maria', 'Wiśniewska', '888999000', 'maria.w@example.com'),
('Tomasz', 'Lewandowski', '111222333', 't.lewa@example.com');

INSERT INTO rooms (room_number, room_type, price_per_night, is_available) VALUES 
('101', 'single', 180.00, 'Y'),
('102', 'quadruple', 300.00, 'N'),
('103', 'double', 520.00, 'Y'),
('104', 'single', 190.00, 'N'),
('105', 'triple', 310.00, 'Y');

INSERT INTO services (service_name, service_price) VALUES 
('Breakfast', 40.00),
('Airport Transfer', 120.00),
('Spa Access', 200.00),
('Parking', 30.00),
('Late Checkout', 70.00);

INSERT INTO reservations (id_guest, id_room, start_date, end_date, total_price) VALUES 
(1, 1, DATE '2025-06-01', DATE '2025-06-05', 1200.00),
(2, 2, DATE '2025-06-10', DATE '2025-06-12', 360.00),
(3, 3, DATE '2025-06-03', DATE '2025-06-04', 310.00),
(4, 4, DATE '2025-06-01', DATE '2025-06-07', 3120.00),
(5, 5, DATE '2025-06-05', DATE '2025-06-06', 190.00);

INSERT INTO reservation_services (id_reservation, id_service) VALUES 
(1, 1), -- breakfast
(2, 2), -- airport transfer
(3, 4), -- parking
(4, 3), -- spa
(5, 1), -- breakfast
(1, 3), -- spa
(5, 5); -- late checkout

INSERT INTO payments (id_reservation, payment_date, amount, payment_method) VALUES 
(1, DATE '2025-06-01', 1200.00, 'Card'),
(2, DATE '2025-06-10', 360.00, 'Cash'),
(3, DATE '2025-06-03', 310.00, 'Card'),
(4, DATE '2025-06-01', 3120.00, 'Transfer'),
(5, DATE '2025-06-05', 190.00, 'Card');
