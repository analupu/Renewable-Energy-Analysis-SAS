%let path = /home/&sysuserid/Proiect Curs;
libname curs1 "&path";

/* 1. Reading and Initial Processing */
data curs1.energie_eficienta;
    infile "&path/energie_regresie.csv" dsd dlm=',' firstobs=2;
    input Consumption Wind Hydroelectric Solar Hour Weekday :$12.;

    total_verde = Wind + Hydroelectric + Solar;
    procent_verde = (total_verde / Consumption) * 100;

    if procent_verde < 20 then nivel_eficienta = "Low";
    else if procent_verde < 50 then nivel_eficienta = "Medium";
    else nivel_eficienta = "High";
run;


/* 2. Chart: Green energy efficiency by hour */
proc sgplot data=curs1.energie_eficienta;
    vbar Hour / group=nivel_eficienta groupdisplay=cluster stat=freq;
    title "Green Energy Efficiency Distribution by Hour";
run;


/* 3. Average green energy percentage by weekday */
proc means data=curs1.energie_eficienta noprint;
    class Weekday;
    var procent_verde;
    output out=medii_weekday mean=media_verde;
run;

proc sgplot data=medii_weekday;
    vbar Weekday / response=media_verde;
    title "Average Green Energy Percentage by Weekday";
run;


/* 4. Boxplot: daily variation */
proc sgplot data=curs1.energie_eficienta;
    vbox procent_verde / category=Weekday;
    title "Green Energy Percentage Distribution by Weekday";
run;


/* 6. Time: daily simulation and month/year transformation */
data curs1.lunar;
    set curs1.energie_eficienta;
    zi = int((_N_-1) / 24);
    Data = '01JAN2019'd + zi;
    format Data date9.;
    Luna = month(Data);
    An = year(Data);
run;

/* 7. Line plot: daily evolution of green energy percentage */
proc sort data=curs1.lunar;
    by Data;
run;

proc sgplot data=curs1.lunar;
    series x=Data y=procent_verde;
    title "Daily Evolution of Green Energy Percentage";
run;


/* 9. Annual growth simulation + ML model  */
data curs1.simulat;
    set curs1.lunar;
    if _N_ <= 9000 then Year = 2019;
    else if _N_ <= 18000 then Year = 2020;
    else Year = 2021;

    procent_verde_sim = procent_verde + (Year - 2019) * 3;
run;

proc glmselect data=curs1.simulat;
    class Weekday;
    model procent_verde_sim = Year Hour Weekday Wind Solar Hydroelectric / selection=stepwise;
    title "ML Model: Estimating Simulated Green Energy Percentage";
run;


/* 10. Chart: simulated annual evolution  */
proc means data=curs1.simulat noprint;
    class Year;
    var procent_verde_sim;
    output out=an_avg mean=avg_verde_sim;
run;


proc sgplot data=an_avg;
    vbar Year / response=avg_verde_sim datalabel fillattrs=(color=green);
    yaxis label="Procent mediu energie verde simulată (%)";
    title "Simulated Evolution of Renewable Energy (2019–2021)";
run;


/* 11. Pie chart: share of renewable sources */
proc means data=curs1.energie_eficienta noprint;
    var Wind Hydroelectric Solar;
    output out=suma_totala sum=wind_sum hydro_sum solar_sum;
run;

data pie_data;
    set suma_totala;
    label = "Wind Energy"; value = wind_sum; output;
    label = "Hydroelectric Energy"; value = hydro_sum; output;
    label = "Solar Energy"; value = solar_sum; output;
    keep label value;
run;

proc gchart data=pie_data;
    pie label / sumvar=value
                value=inside
                percent=outside
                slice=outside
                coutline=black;
    title "Share of Renewable Energy Sources";
run;
quit;

/* 12. Distribution of energy efficiency levels */
proc sgplot data=curs1.energie_eficienta;
    vbar nivel_eficienta / stat=freq datalabel;
    title "Distribution of Energy Efficiency Levels";
run;


/* 13. Sources per day (24 hours) */
data zi_exemplu;
    set curs1.energie_eficienta;
    if _N_ <= 24;
run;

proc sgplot data=zi_exemplu;
    series x=Hour y=Wind / lineattrs=(pattern=solid thickness=2);
    series x=Hour y=Hydroelectric / lineattrs=(pattern=dash thickness=2);
    series x=Hour y=Solar / lineattrs=(pattern=dot thickness=2);
    title "Renewable Energy Sources on First Day";
    yaxis label="Energy Value";
run;


/* 14. Heatmap: solar intensity by hours and days */
proc means data=curs1.energie_eficienta nway;
    class Hour Weekday;
    var Solar;
    output out=heat_avg mean=avg_solar;
run;

proc sgplot data=heat_avg;
    scatter x=Hour y=Weekday / markerattrs=(symbol=squarefilled size=20) 
                              colorresponse=avg_solar 
                              colormodel=(white yellow orange red);
    title "Average Solar Energy Intensity by Hour and Day (Heatmap)";
run;


/* -------------------------------- */
/* Training/test split: 70% training */
proc surveyselect data=curs1.simulat out=verde_sampled
    samprate=0.7 outall method=srs seed=123;
run;

data verde_train verde_test;
    set verde_sampled;
    if selected = 1 then output verde_train;
    else output verde_test;
run;

proc glmselect data=verde_train;
    class Weekday;
    model procent_verde_sim = Year Hour Weekday Wind Solar Hydroelectric /
        selection=stepwise(select=SL) stats=all;
    store out=model_verde;
run;

proc plm restore=model_verde;
    score data=verde_test out=predicted_verde predicted;
run;

/* Visualization: predictions vs actual values */
proc sgplot data=predicted_verde;
    scatter x=procent_verde_sim y=predicted / markerattrs=(symbol=circlefilled color=blue);
    lineparm x=0 y=0 slope=1 / lineattrs=(color=red pattern=shortdash);
    title "Predictions vs Actual Values - Green Energy";
    xaxis label="Actual Value";
    yaxis label="Model Prediction";
run;

/* Calculate error */
data evaluare;
    set predicted_verde;
    eroare = predicted - procent_verde_sim;
    eroare2 = eroare**2;
run;

/* Mean Squared Error */
proc means data=evaluare mean;
    var eroare2;
    output out=rmse mean=mean_squared;
run;

/* RMSE */
data evaluare_finala;
    set rmse;
    RMSE = sqrt(mean_squared);
run;









