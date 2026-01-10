library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_add : in std_logic_vector(15 downto 0);
        o_done : out std_logic;
        o_mem_addr : out std_logic_vector(15 downto 0);
        i_mem_data : in std_logic_vector(7 downto 0);
        o_mem_data : out std_logic_vector(7 downto 0);
        o_mem_we : out std_logic;
        o_mem_en : out std_logic
    );
end project_reti_logiche;


architecture Behavioral of project_reti_logiche is
    -- DICHIARAZIONE COSTANTI
    constant MIN_VAL : signed(17 downto 0) := TO_SIGNED(-128, 18); -- 18 è il numero di bit necessario per rappresentare il risultato intermedio
    constant MAX_VAL : signed(17 downto 0) := TO_SIGNED(127, 18);
    constant FILTER3_SHIFT : unsigned(15 downto 0) := to_unsigned(1, 16); -- il primo coefficiente del filtro 3 come shift
    constant FILTER5_SHIFT : unsigned(15 downto 0) := to_unsigned(8, 16); -- il primo coefficiente del filtro 5 come shift
    constant W_START_SHIFT : unsigned(15 downto 0) := to_unsigned(4, 16); -- shift da effettuare poichè i primi 4 valori sono già stati caricati in finestra
    constant NUM_COEFFS : integer := 7; -- numero dei coefficienti
    constant NUM_WINDOW : integer := 7; -- numero di posti della finestra
    constant MAX_W_INDEX : integer := 3; -- al primo passo la finestra carica i primi 4 valori (nelle posizioni 3 + i, con 0<=i<=3)
    constant W_SHIFT : unsigned(15 downto 0) := to_unsigned(2 * NUM_COEFFS + 3, 16); -- 17 in questo caso (2 * 7 + 3)
    
    -- DICHIARAZIONE SEGNALI
    type state_type is (
        IDLE, -- stato iniziale
        GET_K1, -- legge k1
        GET_K2, -- store di k1 e lettura di k2
        GET_S, -- calcola k e legge s
        STORE_S, -- store di s e legge il primo coefficiente
        STORE_C, -- store del coefficiente e lettura o del prossimo coefficiente o del prossimo valore
        STORE_W, -- store in finestra del valore e lettura del prossimo
        COMPUTE_R, -- calcola il risultato e lo scrive in memoria
        GET_NEXT, -- legge il prossimo valore
        SHIFT_WINDOW, -- effettua lo shift della finestra
        DONE -- stato finale
        );
    signal next_state, current_state: state_type;
    
    signal k1: std_logic_vector(7 downto 0); -- immagazzina k1 per poi calcolare k e gli indirizzi che dipendono da esso
    
    signal current_addr: unsigned(15 downto 0); -- indirizzo corrente dal cui leggere / scrivere
    signal w_addr : unsigned(15 downto 0); -- indirizzo utilizzato nella fase finale per leggere nuovi valori mentre current_addr punta all'indirizzo di scrittura
    signal w_start_addr : unsigned(15 downto 0); -- indirizzo al quale cominciano i valori da leggere
    signal r_start_addr : unsigned(15 downto 0); -- indirizzo al quale cominciare a scrivere i risultati
    signal r_end_addr : unsigned(15 downto 0); -- primo indirizzo successivo alla fine dei risultati
    
    signal s : std_logic; -- bit che rappresenta il tipo di filtro (0: ordine 3, 1: ordine 5)
    
    type coeffs_array is array(0 to NUM_COEFFS - 1) of integer range -128 to 127;
    signal coeffs : coeffs_array; -- array dei coefficienti del filtro
    signal c_index : integer range 0 to NUM_COEFFS - 1;
    
    type window_array is array(0 to NUM_WINDOW - 1) of integer range -128 to 127;
    signal window : window_array; -- finestra a scorrimento utilizzata per il calcolo dei risultati
    signal w_index : integer range 0 to MAX_W_INDEX;
    
begin
    
    reg_update: process(i_clk, i_rst)
    begin
        if i_rst = '1' then 
            current_state <= IDLE; -- ritorno allo stato idle
            
        elsif rising_edge(i_clk) then 
            current_state <= next_state; -- aggiornamento dello stato
            
            case current_state is
                when IDLE => -- inizializzazione dei registri
                    current_addr <= (others => '0');
                    r_start_addr <= (others => '0');
                    w_start_addr <= (others => '0');
                    w_addr <= (others => '0');

                    k1 <= (others => '0');
                    
                    s <= '0';
                    coeffs <= (others => 0);
                    
                    window <= (others => 0);
                    c_index <= 0;
                    w_index <= 0;
            
                when GET_K1 => -- calcolo gli indirizzi che dipendono esclusivamente da i_add
                    current_addr <= unsigned(i_add) + 1;
                    w_start_addr <= unsigned(i_add) + W_SHIFT; 
                
                when GET_K2 => 
                    k1 <= i_mem_data;
                    current_addr <= current_addr + 1;
                
                when GET_S => -- calcolo gli indirizzi che dipendono da k
                    r_start_addr <= w_start_addr + unsigned(k1 & i_mem_data);
                    r_end_addr <= w_start_addr + unsigned(k1 & i_mem_data) + unsigned(k1 & i_mem_data);
                
                when STORE_S =>
                    s <= i_mem_data(0);
                    
                    if i_mem_data(0) = '0' then -- scelgo i coefficienti del filtro selezionato
                        current_addr <= current_addr + FILTER3_SHIFT + 1;
                    else
                        current_addr <= current_addr + FILTER5_SHIFT + 1;
                    end if;
                
                when STORE_C =>
                    coeffs(c_index) <= to_integer(signed(i_mem_data));
                    
                    if c_index < NUM_COEFFS - 1 then -- continuo a leggere e caricare coefficienti
                        c_index <= c_index + 1;
                        current_addr <= current_addr + 1;
                    else 
                        current_addr <= w_start_addr + 1;
                    end if;
                
                when STORE_W =>
                    window(w_index + 3) <= to_integer(signed(i_mem_data)); -- +3 perchè parto dal centro (se un valore è fuori dalla sequenza data viene considerato 0)
                    
                    if w_index < MAX_W_INDEX then -- continuo a leggere e caricare valori in finestra
                        w_index <= w_index + 1;
                        current_addr <= current_addr + 1;
                    else 
                        current_addr <= r_start_addr;
                        w_addr <= w_start_addr + W_START_SHIFT;
                    end if;

                when SHIFT_WINDOW =>
                    for i in 0 to NUM_WINDOW - 2 loop -- sposto a sinistra tutti i valori tranne l'ultimo
                        window(i) <= window(i + 1);
                    end loop;
                    
                    -- assegno l'ultimo valore
                    if w_addr < r_start_addr then -- valore dalla memoria
                        window(NUM_WINDOW - 1) <= to_integer(signed(i_mem_data));
                    else -- 0 se oltre la sequenza iniziale
                        window(NUM_WINDOW - 1) <= 0;
                    end if;
                    
                    current_addr <= current_addr + 1;
                    w_addr <= w_addr + 1;
                
                when others =>
                    null;
            end case;
        end if;
    end process;
    
    state_transition: process(current_state, i_rst, i_start, c_index, w_addr, r_start_addr, r_end_addr, current_addr, w_index)
    begin
        case current_state is
            when IDLE =>
                if i_start = '1' and i_rst = '0' then -- condizione di inizio
                    next_state <= GET_K1;
                else
                    next_state <= IDLE;
                end if;
                
            when GET_K1 => next_state <= GET_K2;
            
            when GET_K2 => next_state <= GET_S;              
            
            when GET_S => next_state <= STORE_S;      
            
            when STORE_S => next_state <= STORE_C;     
            
            when STORE_C =>
                if c_index < NUM_COEFFS - 1 then  -- condizione di fine caricamento coefficienti
                    next_state <= STORE_C;
                else 
                    next_state <= STORE_W;
                end if;
            
            when STORE_W =>
                if w_index < MAX_W_INDEX then -- condizione di fine caricamento valori in finestra
                    next_state <= STORE_W;
                else 
                    next_state <= COMPUTE_R;     
                end if;      
            
            when COMPUTE_R =>
                if current_addr < r_end_addr then -- non ho ancora finito di scrivere i risultati
                    if w_addr < r_start_addr then -- non ho ancora finito di leggere i valori della sequenza
                        next_state <= GET_NEXT;
                    else -- ho finito i valori della sequenza (devo usare 0)
                        next_state <= SHIFT_WINDOW;
                    end if;
                else next_state <= DONE; -- ho finito di scrivere i risultati
                end if;
            
            when GET_NEXT => next_state <= SHIFT_WINDOW;
            
            when SHIFT_WINDOW => next_state <= COMPUTE_R;
            
            when DONE =>
                if i_start = '0' then -- attendo che i_start venga abbassato
                    next_state <= IDLE;             
                else
                    next_state <= DONE;
                end if;
                
            when others => 
                next_state <= IDLE;
        end case;
    end process;

    output_logic: process(current_state, i_add, current_addr, i_mem_data, coeffs, window, s, w_addr, r_start_addr)
    variable temp_res, t1, t2, t3, t4 : signed(17 downto 0); -- variabili usate per il calcolo del risultato
    
    begin
        -- valori predefiniti delle uscite
        o_done <= '0';
        o_mem_addr <= (others => '0');
        o_mem_data <= (others => '0');
        o_mem_en <= '0';
        o_mem_we <= '0';
        
        temp_res := (others => '0');
        t1 := (others => '0');
        t2 := (others => '0');
        t3 := (others => '0');
        t4 := (others => '0');
        
        case current_state is
            when IDLE => 
                o_done <= '0';
                o_mem_addr <= (others => '0');
                o_mem_data <= (others => '0');
                o_mem_en <= '0';
                o_mem_we <= '0';
            
            when GET_K1 => -- stato di lettura all'indirizzo i_add (k1)
                o_mem_en <= '1';
                o_mem_we <= '0';
                o_mem_addr <= i_add;
            
            when GET_K2 => -- lettura di k2
                o_mem_en <= '1';
                o_mem_we <= '0';
                o_mem_addr <= std_logic_vector(current_addr);    
            
            when GET_S => -- lettura di s
                o_mem_en <= '1';
                o_mem_we <= '0';
                o_mem_addr <= std_logic_vector(current_addr);
            
            when STORE_S => -- lettura del primo coefficiente del filtro
                o_mem_en <= '1';
                o_mem_we <= '0';
                if i_mem_data(0) = '0' then
                    o_mem_addr <= std_logic_vector(current_addr + FILTER3_SHIFT);
                else
                    o_mem_addr <= std_logic_vector(current_addr + FILTER5_SHIFT);
                end if;

            when STORE_C => -- lettura del coefficiente succesivo o del primo valore da mettere in finestra
                o_mem_en <= '1';
                o_mem_we <= '0';
                if c_index < NUM_COEFFS - 1 then
                    o_mem_addr <= std_logic_vector(current_addr);
                else
                    o_mem_addr <= std_logic_vector(w_start_addr);
                end if;
            
            when STORE_W => -- lettura del prossimo valore da mettere in finestra
                if w_index < MAX_W_INDEX then 
                    o_mem_en <= '1';
                    o_mem_we <= '0';
                    o_mem_addr <= std_logic_vector(current_addr);
                else 
                    null;    
                end if;
            
            when COMPUTE_R => -- calcolo del risultato
                temp_res := (others => '0');
                
                if s = '0' then -- filtro di ordine 3
                    for i in 1 to NUM_WINDOW - 2 loop -- uso i valori con indice 3 +- i, 0<=i<=2;
                        temp_res := temp_res + TO_SIGNED(coeffs(i) * window(i), 18);
                    end loop;
                    
                    -- normalizzazione con n=12
                    t1 := shift_right(temp_res, 4);
                    t2 := shift_right(temp_res, 6);
                    t3 := shift_right(temp_res, 8);
                    t4 := shift_right(temp_res, 10);
                    
                    -- correzione dello shift
                    if temp_res < TO_SIGNED(0, 18) then
                        t1 := t1 + 1;
                        t2 := t2 + 1;
                        t3 := t3 + 1;
                        t4 := t4 + 1;
                    end if;
                    
                    temp_res := t1 + t2 + t3 + t4;
                    
                else -- filtro di ordine 5
                    for i in 0 to NUM_WINDOW - 1 loop -- uso i valori con indice 3 +- i, 0<=i<=3;
                        temp_res := temp_res + TO_SIGNED(coeffs(i) * window(i), 18);
                    end loop;
                    
                    -- normalizzazione con n=60
                    t1 := shift_right(temp_res, 6);
                    t2 := shift_right(temp_res, 10);
                    
                    -- correzione dello shift
                    if temp_res < TO_SIGNED(0, 18) then
                        t1 := t1 + 1;
                        t2 := t2 + 1;
                    end if;
                    
                    temp_res := t1 + t2;
                end if;
                
                -- saturazione nell'intervallo [-128, 127] 
                if temp_res < MIN_VAL then
                    temp_res := MIN_VAL;
                 elsif temp_res > MAX_VAL then
                    temp_res := MAX_VAL;
                end if;
                
                -- scrittura del risultato
                o_mem_en <= '1';
                o_mem_we <= '1';
                o_mem_data <= std_logic_vector(temp_res(7 downto 0));
                o_mem_addr <= std_logic_vector(current_addr);
            
            when GET_NEXT => -- lettura del nuovo valore
                o_mem_en <= '1';
                o_mem_we <= '0';
                o_mem_addr <= std_logic_vector(w_addr);
            
            when DONE => -- stato finale
                o_mem_en <= '0';
                o_mem_we <= '0';
                o_done <= '1';
            
            when others =>
                o_done <= '0';
                o_mem_addr <= (others => '0');
                o_mem_data <= (others => '0');
                o_mem_en <= '0';
                o_mem_we <= '0';
        end case;
    end process;

end Behavioral;