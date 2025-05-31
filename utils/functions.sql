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

-- is_room_available 
-- This function returns a boolean true or false depending on the availability of the room in a certain date. It takes two IN arguments as an input. 
-- Start_date as a date of the start of the reservation
-- End_date as a date of the end of the reservation
-- Room_id as the id of the room that is going to be checked. 
CREATE OR REPLACE FUNCTION is_room_available (
    p_start_date IN DATE,
    p_end_date   IN DATE,
    p_room_id    IN NUMBER
)
RETURN CHAR
IS
    v_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_exists
    FROM rooms
    WHERE id_room = p_room_id;

    IF v_exists = 0 THEN
        RETURN 'N';
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
        RETURN 'N'; 
    ELSE
        RETURN 'Y'; 
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        RETURN 'N'; 
END;
/

-- calculate_tax_or_no_tax_income
-- • Is_taxed as a Boolean describing wheather the calculated income should be 
-- taxed  
-- • Income_date as a date of the day which income is going to be calculated.
CREATE OR REPLACE FUNCTION calculate_tax_or_no_tax_income (
    p_is_taxed     IN CHAR,
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

    IF p_is_taxed = 'Y' THEN
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
