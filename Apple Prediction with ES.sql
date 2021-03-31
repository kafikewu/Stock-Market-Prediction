%sql
select count(*) from cleaned_APPLE_dataset_TRAIN;

%sql
--create view cleaned_apple_dataset as select day, close from apple_dataset order by day;
--CREATE VIEW cleaned_apple_dataset_TEST AS
--SELECT * FROM cleaned_apple_dataset
--MINUS
--select * from cleaned_apple_dataset where rownum <= 1170;
--CREATE VIEW cleaned_apple_dataset_TRAIN AS
--select * from cleaned_apple_dataset where rownum <= 1170;

%sql
select * from cleaned_apple_dataset_test;

%script

BEGIN DBMS_DATA_MINING.DROP_MODEL('ESM_APPLE_FORECAST_1');
EXCEPTION WHEN OTHERS THEN NULL; END;
/
DECLARE
    v_setlst DBMS_DATA_MINING.SETTING_LIST;
BEGIN
    v_setlst(dbms_data_mining.ALGO_NAME)    := dbms_data_mining.ALGO_EXPONENTIAL_SMOOTHING;
    V_setlst(dbms_data_mining.EXSM_INTERVAL):= dbms_data_mining.EXSM_INTERVAL_DAY;-- accumulation int'l = quarter
    V_setlst(dbms_data_mining.EXSM_PREDICTION_STEP) := '4';                -- prediction step = 4 quarters
    V_setlst(dbms_data_mining.EXSM_MODEL)   := dbms_data_mining.EXSM_SIMPLE;   -- ESM model = Holt-Winters
    --V_setlst(dbms_data_mining.EXSM_SEASONALITY) := '1170';
    V_setlst(dbms_data_mining.EXSM_OPT_CRITERION) := dbms_data_mining.EXSM_OPT_CRIT_MSE;
    DBMS_DATA_MINING.CREATE_MODEL2(
        MODEL_NAME           => 'ESM_APPLE_FORECAST_1',
        MINING_FUNCTION      => 'TIME_SERIES',
        DATA_QUERY           => 'select * from cleaned_APPLE_dataset_TRAIN',
        SET_LIST             => v_setlst,
        CASE_ID_COLUMN_NAME  => 'DAY',
        TARGET_COLUMN_NAME   =>'CLOSE');
END;


%sql
SELECT SETTING_NAME, SETTING_VALUE
  FROM USER_MINING_MODEL_SETTINGS
  WHERE MODEL_NAME = UPPER('ESM_APPLE_FORECAST_1')
  ORDER BY SETTING_NAME;
  
%sql

SELECT NAME, round(NUMERIC_VALUE,4), STRING_VALUE 
  FROM DM$VGESM_APPLE_FORECAST_1
  ORDER BY NAME;
  
%sql

-- Sort results by descending date so latest points are shown first
-- The model predicts 4 values into the future with LOWER and UPPER condifence bounds

SELECT TO_CHAR(CASE_ID,'YYYY-MON-DD') DATE_ID, 
       round(VALUE,2) ACTUAL_PRICE, 
       round(PREDICTION,2) FORECAST_PRICE, 
       round(LOWER,2) LOWER_BOUND, round(UPPER,2) UPPER_BOUND
  FROM DM$VPESM_APPLE_FORECAST_1
  ORDER BY CASE_ID;

%sql
SELECT TO_CHAR(B.DAY,'YYYY-MON-DD')DAY, T.PREDICTION, B.CLOSE, (T.PREDICTION - B.CLOSE)
  FROM DM$VPESM_APPLE_FORECAST_1 T, cleaned_apple_dataset_test B
  WHERE T.CASE_ID = B.DAY;
  
%script
DECLARE
    MEAN NUMBER;
    NUMBER_OF_ROWS INT;
    RMSE NUMBER := 0;
    MSE NUMBER := 0;
    MAE NUMBER := 0;
BEGIN
    SELECT COUNT(*), SUM(POWER((B.CLOSE - T.PREDICTION), 2)) INTO NUMBER_OF_ROWS, MEAN
    FROM DM$VPESM_apple_FORECAST_1 T, cleaned_apple_dataset_test B
    WHERE T.CASE_ID = B.DAY;
    RMSE := SQRT(MEAN/NUMBER_OF_ROWS);
    MSE := MEAN/NUMBER_OF_ROWS;
    DBMS_OUTPUT.PUT_LINE('RMSE ' || TO_CHAR(ROUND(RMSE, 2)));
    DBMS_OUTPUT.PUT_LINE('MSE ' || TO_CHAR(ROUND(MSE, 2)));
    SELECT COUNT(*), SUM(ABS(B.CLOSE - T.PREDICTION)) INTO NUMBER_OF_ROWS, MEAN
    FROM DM$VPESM_apple_FORECAST_1 T, cleaned_apple_dataset_test B
    WHERE T.CASE_ID = B.DAY;
    MAE := MEAN/NUMBER_OF_ROWS;
    DBMS_OUTPUT.PUT_LINE('MAE ' || TO_CHAR(ROUND(MAE, 2)));
END;