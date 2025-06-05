-- See_free_rooms_on_date 
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

    UPDATE rooms SET is_available = 'N'
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
        SET is_available = 'Y'
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
    SET is_available = 'N'
    WHERE id_room IN (
        SELECT id_room
        FROM reservations
        WHERE status = 'Active'
          AND TRUNC(SYSDATE) BETWEEN TRUNC(start_date) AND TRUNC(end_date)
    );

    UPDATE rooms
    SET is_available = 'Y'
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

-- update_service
-- This procedure updates the name and price of an existing service. It uses three IN arguments:
-- • p_id_service – the ID of the service that is going to have its details changed
-- • p_new_service_name – the new name for the service
-- • p_new_service_price – the new price for the service
CREATE OR REPLACE PROCEDURE update_service (
    p_id_service        IN services.id_service%TYPE,
    p_new_service_name  IN services.service_name%TYPE,
    p_new_service_price IN services.service_price%TYPE
)
IS
BEGIN
    UPDATE services
    SET service_name = p_new_service_name,
        service_price = p_new_service_price
    WHERE id_service = p_id_service;

    IF SQL%NOTFOUND THEN
        RAISE_APPLICATION_ERROR(-20010, 'Service with ID ' || p_id_service || ' not found.');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
/

-- add_services_to_existing_reservation
-- This procedure adds new services to an already existing reservation and updates the reservation's total price. It uses two IN arguments:
-- • p_id_reservation – the ID of the reservation to which services will be added
-- • p_new_service_ids – a table collection of service IDs that are to be added to the reservation
CREATE OR REPLACE PROCEDURE add_services_to_existing_reservation (
    p_id_reservation   IN reservations.id_reservation%TYPE,
    p_new_service_ids  IN service_id_table
)
IS
    v_reservation_exists NUMBER;
    v_current_room_id reservations.id_room%TYPE;
    v_current_start_date reservations.start_date%TYPE;
    v_current_end_date reservations.end_date%TYPE;
    v_all_service_ids service_id_table;
    v_new_total_price reservations.total_price%TYPE;
BEGIN
    SELECT COUNT(*), id_room, start_date, end_date
    INTO v_reservation_exists, v_current_room_id, v_current_start_date, v_current_end_date
    FROM reservations
    WHERE id_reservation = p_id_reservation
    GROUP BY id_room, start_date, end_date;

    IF v_reservation_exists = 0 THEN
        RAISE_APPLICATION_ERROR(-20011, 'Reservation with ID ' || p_id_reservation || ' not found.');
    END IF;

    FOR i IN 1 .. p_new_service_ids.COUNT LOOP
        INSERT INTO reservation_services (id_reservation, id_service)
        VALUES (p_id_reservation, p_new_service_ids(i));
    END LOOP;

    SELECT id_service BULK COLLECT INTO v_all_service_ids
    FROM reservation_services
    WHERE id_reservation = p_id_reservation;

    v_new_total_price := calculate_total_price(
        p_id_services => v_all_service_ids,
        p_id_room     => v_current_room_id,
        p_start_date  => v_current_start_date,
        p_end_date    => v_current_end_date
    );

    UPDATE reservations
    SET total_price = v_new_total_price
    WHERE id_reservation = p_id_reservation;

    DBMS_OUTPUT.PUT_LINE('Services successfully added to reservation ' || p_id_reservation || ' and total price updated.');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error adding services to reservation: ' || SQLERRM);
        RAISE;
END;
/