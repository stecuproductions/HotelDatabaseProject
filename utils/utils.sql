--Functions

-- calculate_total_price: 
-- This function returns  the total price of the reservation. It takes two IN arguments as an input: 
-- id_services as an table of reservation services ids to calculate their total price. 
-- Id_room as an integer to calculate total price using the formula price_per_day  * days 
-- Start_date as a date  as a date of the start of the reservation 
-- End_date as a date of the end of the reservation 

CREATE OR REPLACE TYPE service_id_table AS TABLE OF NUMBER;
/
CREATE OR REPLACE FUNCTION calculate_total_price (
    p_id_services IN service_id_table,
    p_id_room     IN NUMBER,
    p_start_date  IN DATE,
    p_end_date    IN DATE
)
RETURN NUMBER
IS
    v_total_price         NUMBER(10, 2) := 0;
    v_price_per_night     NUMBER(10, 2);
    v_days                NUMBER;
    v_service_price       NUMBER(10, 2);
BEGIN
    v_days := TRUNC(p_end_date) - TRUNC(p_start_date);
    IF v_days < 1 THEN
        v_days := 1; 
    END IF;

    SELECT price_per_night INTO v_price_per_night
    FROM rooms
    WHERE id_room = p_id_room;

    v_total_price := v_days * v_price_per_night;

    FOR i IN 1 .. p_id_services.COUNT LOOP
        SELECT service_price INTO v_service_price
        FROM services
        WHERE id_service = p_id_services(i);

        v_total_price := v_total_price + v_service_price;
    END LOOP;

    RETURN v_total_price;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RAISE_APPLICATION_ERROR(-20001, 'Invalid room ID or service ID');
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20002, 'Error calculating total price: ' || SQLERRM);
END;
/

--Usage
DECLARE
    price NUMBER;
    services service_id_table := service_id_table(1, 2, 3); 
BEGIN
    price := calculate_total_price(services, 1, DATE '2025-06-01', DATE '2025-06-05');
    DBMS_OUTPUT.PUT_LINE('Total price: ' || price);
END;
/


--is_room_available 
-- This function returns a boolean true or false depending on the availability of the room in a certain date. It takes two IN arguments as an input. 
-- Start_date as a date of the start of the reservation
-- End_date as a date of the end of the reservation
-- Room_id as the id of the room that is going to be checked. 
CREATE OR REPLACE FUNCTION is_room_available (
    p_start_date IN DATE,
    p_end_date   IN DATE,
    p_room_id    IN NUMBER
)
RETURN BOOLEAN
IS
    v_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_exists
    FROM rooms
    WHERE id_room = p_room_id;

    IF v_exists = 0 THEN
        RETURN FALSE;
    END IF;

    SELECT COUNT(*) INTO v_exists
    FROM reservations
    WHERE id_room = p_room_id
      AND status IN ('Awaiting', 'Active')
      AND (
            start_date <= p_end_date
        AND end_date >= p_start_date
      );

    IF v_exists > 0 THEN
        RETURN FALSE; 
    ELSE
        RETURN TRUE; 
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE; 
END;
/

--Usage
DECLARE
    available BOOLEAN;
BEGIN
    available := is_room_available(DATE '2025-07-01', DATE '2025-07-05', 1);

    IF available THEN
        DBMS_OUTPUT.PUT_LINE('Room is available!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Room is NOT available!');
    END IF;
END;
/

--calculate_tax_or_no_tax_income
-- • Is_taxed as a Boolean describing wheather the calculated income should be 
-- taxed  
-- • Income_date as a date of the day which income is going to be calculated.
CREATE OR REPLACE FUNCTION calculate_tax_or_no_tax_income (
    p_is_taxed     IN BOOLEAN,
    p_income_date  IN DATE
)
RETURN NUMBER
IS
    v_raw_income NUMBER(10,2) := 0;
    v_final_income NUMBER(10,2);
    v_tax_rate CONSTANT NUMBER := 0.23; -- 23% VAT
BEGIN
    SELECT NVL(SUM(amount), 0)
    INTO v_raw_income
    FROM payments
    WHERE TRUNC(payment_date) = TRUNC(p_income_date);

    IF p_is_taxed THEN
        v_final_income := v_raw_income * (1 - v_tax_rate);
    ELSE
        v_final_income := v_raw_income;
    END IF;

    RETURN v_final_income;

EXCEPTION
    WHEN OTHERS THEN
        RETURN 0; 
END;
/

--Procedures

--See_free_rooms_on_date 
-- This function returns free rooms on the given date takes two IN arguments as an input 
-- and returns the records of free rooms. It takes three IN agruments 
-- Start date 
-- End date 
-- Room type 
 
CREATE OR REPLACE PROCEDURE see_free_rooms_on_date (
    p_start_date IN DATE,
    p_end_date   IN DATE,
    p_room_type  IN VARCHAR2
)
IS
    CURSOR free_rooms IS
        SELECT id_room, room_number, room_type, price_per_night
        FROM rooms r
        WHERE r.room_type = p_room_type
          AND NOT EXISTS (
              SELECT 1
              FROM reservations res
              WHERE res.id_room = r.id_room
                AND (
                    res.start_date <= p_end_date AND res.end_date >= p_start_date
                )
          );

    room_rec free_rooms%ROWTYPE;
BEGIN
    OPEN free_rooms;
    LOOP
        FETCH free_rooms INTO room_rec;
        EXIT WHEN free_rooms%NOTFOUND;
        DBMS_OUTPUT.PUT_LINE(
            'Room ID: ' || room_rec.id_room || 
            ', Number: ' || room_rec.room_number ||
            ', Type: ' || room_rec.room_type ||
            ', Price: ' || room_rec.price_per_night
        );
    END LOOP;
    CLOSE free_rooms;
END;
/

SET SERVEROUTPUT ON;
BEGIN
    see_free_rooms_on_date(
        TO_DATE('2026-06-01', 'YYYY-MM-DD'),
        TO_DATE('2028-06-05', 'YYYY-MM-DD'),
        'double'
    );
END;

-- add_reservation_with_services 
-- Thisthis procedure  adds a reservation to a database. It takes five in arguments: 
-- Id_guest  - id of a guest making a reservation 
-- Id_room – id of a room that is being booked 
-- Start_date – date of the beginning of the stay 
-- End_date – date of the end of the stay 
-- id_services as an table of reservation services. 
-- This procedure also handles possible exceptions (e.g  - the room is unavailable) and sets total_price attribute using calculate_total_price function. 
CREATE OR REPLACE PROCEDURE add_reservation_with_services (
    p_id_guest     IN NUMBER,
    p_id_room      IN NUMBER,
    p_start_date   IN DATE,
    p_end_date     IN DATE,
    p_service_ids  IN service_id_table
)
IS
    v_total_price   NUMBER(10,2);
    v_new_res_id    NUMBER;
    v_room_exists   NUMBER;
    v_room_busy     NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_room_exists
    FROM rooms
    WHERE id_room = p_id_room;

    IF v_room_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Room does not exist');
    END IF;

    SELECT COUNT(*) INTO v_room_busy
    FROM reservations
    WHERE id_room = p_id_room
      AND status IN ('Awaiting', 'Active')
      AND start_date <= p_end_date
      AND end_date >= p_start_date;

    IF v_room_busy > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'Room is already booked for the selected dates');
    END IF;

    v_total_price := calculate_total_price(p_service_ids, p_id_room, p_start_date, p_end_date);

    INSERT INTO reservations(id_guest, id_room, start_date, end_date, total_price, status)
    VALUES (p_id_guest, p_id_room, p_start_date, p_end_date, v_total_price, 'Awaiting')
    RETURNING id_reservation INTO v_new_res_id;

    UPDATE rooms SET isAvailable = 'N'
    WHERE id_room = p_id_room;

    IF p_service_ids IS NOT NULL THEN
        FOR i IN 1 .. p_service_ids.COUNT LOOP
            INSERT INTO reservation_services(id_reservation, id_service)
            VALUES (v_new_res_id, p_service_ids(i));
        END LOOP;
    END IF;

    DBMS_OUTPUT.PUT_LINE('The reservation has been sucessfully added. ID: : ' || v_new_res_id);
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Wystąpił błąd: ' || SQLERRM);
        RAISE;
END;
/
--Usage
DECLARE
    v_service_ids service_id_table := service_id_table(1, 2, 3);
BEGIN
    add_reservation_with_services(1, 1, DATE '2025-07-01', DATE '2025-08-05', v_service_ids);
END;
/

-- cancel_reservation 
-- This procedure cancels the reservation and reservation services related to it. It takes 
-- one in argument: 
-- • id_reservation – the id of the reservation that is going to be canceled
CREATE OR REPLACE PROCEDURE cancel_reservation (
    p_id_reservation IN NUMBER
)
IS
    v_room_id      rooms.id_room%TYPE;
    v_res_status   reservations.status%TYPE;
BEGIN
    SELECT id_room, status INTO v_room_id, v_res_status
    FROM reservations
    WHERE id_reservation = p_id_reservation;

    DELETE FROM reservation_services
    WHERE id_reservation = p_id_reservation;

    UPDATE reservations
    SET status = 'Cancelled'
    WHERE id_reservation = p_id_reservation;

    IF v_res_status = 'Active' THEN
        UPDATE rooms
        SET isAvailable = 'Y'
        WHERE id_room = v_room_id;
    END IF;

    DBMS_OUTPUT.PUT_LINE('Reservation has been successfully cancelled.');

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No reservation found with the given ID.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
        RAISE;
END;
/
--Usage
BEGIN
    cancel_reservation(1); 
END;
/


-- update_room_price 
-- This procedure updates the room price. It uses two in arguments: 
-- • id_room – the id of the room that is going to have its price changed 
-- • new_price _per_night – the new value of the attribute ‘price_per_night
CREATE OR REPLACE PROCEDURE update_room_price (
    p_id_room         IN NUMBER,
    p_new_price       IN NUMBER
)
IS
    v_room_exists     NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_room_exists
    FROM rooms
    WHERE id_room = p_id_room;

    IF v_room_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Room does not exist');
    END IF;

    UPDATE rooms
    SET price_per_night = p_new_price
    WHERE id_room = p_id_room;

    DBMS_OUTPUT.PUT_LINE('Room price has been successfully updated.');
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No room found with the given ID.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('An unexpected error occurred: ' || SQLERRM);
        RAISE;
END;
/
--Usage
BEGIN
    update_room_price(2, 150.00); 
END;

--Triggers
--Prevent_double_booking 
--It throws an exception when the administrator is trying to book already booked room. 

CREATE OR REPLACE TRIGGER prevent_double_booking
BEFORE INSERT OR UPDATE ON reservations
FOR EACH ROW
DECLARE
    v_conflict_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_conflict_count
    FROM reservations
    WHERE id_room = :NEW.id_room
      AND status IN ('Awaiting', 'Active')
      AND (
            :NEW.start_date <= end_date
        AND :NEW.end_date >= start_date
      )
      AND (:NEW.id_reservation IS NULL OR id_reservation != :NEW.id_reservation);

    IF v_conflict_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20003, 'Double booking not allowed: the room is already booked in the given date range.');
    END IF;
END;
/


-- free_room_on_cancellation 
-- It sets room status to  ‘free’  when the book is CURRENTLY occupied and the reservation is cancelled. 
CREATE OR REPLACE TRIGGER free_room_on_cancellation
AFTER UPDATE ON reservations
FOR EACH ROW
WHEN (
    OLD.status = 'Active' AND NEW.status = 'Cancelled'
)
BEGIN
    UPDATE rooms
    SET isAvailable = 'Y'
    WHERE id_room = :NEW.id_room;
END;
/


-- validate_reservation_dates 
-- It prevents from inserting a reservation with date earlier than todays date. 
CREATE OR REPLACE TRIGGER validate_reservation_dates
BEFORE INSERT OR UPDATE ON reservations
FOR EACH ROW
BEGIN
    IF :NEW.start_date < TRUNC(SYSDATE) OR :NEW.end_date < TRUNC(SYSDATE) THEN
        RAISE_APPLICATION_ERROR(-20004, 'Reservation dates cannot be in the past.');
    END IF;
END;
/

--DATABASE WILL HAVE DBMS_SCHEDULER WHICH WILL SET THE ROOM AVAILABILITY ACCORDING TO CURRENT DATE. 
CREATE OR REPLACE PROCEDURE update_reservations_and_rooms
IS
BEGIN
    UPDATE reservations
    SET status = 'Active'
    WHERE status = 'Awaiting'
      AND TRUNC(start_date) = TRUNC(SYSDATE);

    UPDATE reservations
    SET status = 'Finished'
    WHERE status = 'Active'
      AND TRUNC(end_date) < TRUNC(SYSDATE);

    UPDATE rooms
    SET isAvailable = 'N'
    WHERE id_room IN (
        SELECT id_room
        FROM reservations
        WHERE status = 'Active'
          AND TRUNC(SYSDATE) BETWEEN TRUNC(start_date) AND TRUNC(end_date)
    );

    UPDATE rooms
    SET isAvailable = 'Y'
    WHERE id_room NOT IN (
        SELECT id_room
        FROM reservations
        WHERE status = 'Active'
          AND TRUNC(SYSDATE) BETWEEN TRUNC(start_date) AND TRUNC(end_date)
    );
END;
/


BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name        => 'job_update_reservations_and_rooms',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'update_reservations_and_rooms',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=0; BYMINUTE=0; BYSECOND=0',
        enabled         => TRUE,
        comments        => 'Updates reservation statuses and room availability daily at midnight.'
    );
END;
/
