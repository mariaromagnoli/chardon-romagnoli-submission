/* This code: cleans MMO for our purposes. */

libname mmo "C:\Users\Public\Documents\Charagnoli\RawForCE";
libname mylib "C:\Users\Public\Documents\Charagnoli\01 Intermediate Data\MMO";
libname id "C:\Users\Public\Documents\Charagnoli\01 Intermediate Data\IDs";

/* Step 1: ID Reference */

proc sort data=id.unique_ids nodupkey;
by id_force;
run;

proc sql;
create table ref_id as
select distinct c.id_force
from mmo.MMO_2_2025_F17 c
inner join id.unique_ids u on c.id_force = u.id_force;
quit;

/* Step 2: Contract Retrieval */

data mylib.contract_2023;

if _N_=1 then do;
declare hash h_force(dataset:"ref_id");
h_force.defineKey("id_force");
h_force.defineDone();
end;

set mmo.MMO_2_2023_F17 (keep=id_force PcsEse L_Contrat_SQN DebutCTT FinCTT
							  PreDSN H_Etab_SQN ModeExercice Quali_salaire_base
							  salaire_base salaire_base_mois_complet CP Localite);
year=2023;
if missing(L_Contrat_SQN) then delete;
if input(substr(DebutCTT,1,4),4.) < 2019 then delete;
debut_dt = input(DebutCTT, yymmdd10.);
fin_dt = input(FinCTT, yymmdd10.);
if (fin_dt - debut_dt) < 31 then delete;

if h_force.find()^=0 then delete;
run;

data mylib.contract_2022;

if _N_=1 then do;
declare hash h_force(dataset:"ref_id");
h_force.defineKey("id_force");
h_force.defineDone();
end;

set mmo.MMO_2_2022_F17 (keep=id_force PcsEse L_Contrat_SQN DebutCTT FinCTT
							  PreDSN H_Etab_SQN ModeExercice Quali_salaire_base
							  salaire_base salaire_base_mois_complet CP Localite);
year=2022;
if missing(L_Contrat_SQN) then delete;
if input(substr(DebutCTT,1,4),4.) < 2019 then delete;
debut_dt = input(DebutCTT, yymmdd10.);
fin_dt = input(FinCTT, yymmdd10.);
if (fin_dt - debut_dt) < 31 then delete;
if h_force.find()^=0 then delete;
run;

data mylib.contract_2021;

if _N_=1 then do;
declare hash h_force(dataset:"ref_id");
h_force.defineKey("id_force");
h_force.defineDone();
end;

set mmo.MMO_2_2021_F17 (keep=id_force PcsEse L_Contrat_SQN DebutCTT FinCTT
							  PreDSN H_Etab_SQN ModeExercice Quali_salaire_base
							  salaire_base salaire_base_mois_complet CP Localite);
year=2021;
if missing(L_Contrat_SQN) then delete;
if input(substr(DebutCTT,1,4),4.) < 2019 then delete;
debut_dt = input(DebutCTT, yymmdd10.);
fin_dt = input(FinCTT, yymmdd10.);
if (fin_dt - debut_dt) < 31 then delete;
if h_force.find()^=0 then delete;
run;

data mylib.contract_2020;

if _N_=1 then do;
declare hash h_force(dataset:"ref_id");
h_force.defineKey("id_force");
h_force.defineDone();
end;

set mmo.MMO_2_2020_F17 (keep=id_force PcsEse L_Contrat_SQN DebutCTT FinCTT
							  PreDSN H_Etab_SQN ModeExercice Quali_salaire_base
							  salaire_base salaire_base_mois_complet CP Localite);
year=2020;
if missing(L_Contrat_SQN) then delete;
if input(substr(DebutCTT,1,4),4.) < 2019 then delete;
debut_dt = input(DebutCTT, yymmdd10.);
fin_dt = input(FinCTT, yymmdd10.);
if (fin_dt - debut_dt) < 31 then delete;
if h_force.find()^=0 then delete;
run;


data mylib.contract_2019;

if _N_=1 then do;
declare hash h_force(dataset:"ref_id");
h_force.defineKey("id_force");
h_force.defineDone();
end;

set mmo.MMO_2_2019_F17 (keep=id_force PcsEse L_Contrat_SQN DebutCTT FinCTT
							 PreDSN H_Etab_SQN ModeExercice Quali_salaire_base
							  salaire_base salaire_base_mois_complet CP Localite);
year=2019;
if missing(L_Contrat_SQN) then delete;
if input(substr(DebutCTT,1,4),4.) < 2019 then delete;
debut_dt = input(DebutCTT, yymmdd10.);
fin_dt = input(FinCTT, yymmdd10.);
if (fin_dt - debut_dt) < 31 then delete;
if h_force.find()^=0 then delete;
run;

data mylib.contract_2024;

if _N_=1 then do;
declare hash h_force(dataset:"ref_id");
h_force.defineKey("id_force");
h_force.defineDone();
end;

set mmo.MMO_2_2024_F17 (keep=id_force PcsEse L_Contrat_SQN DebutCTT FinCTT
							  PreDSN H_Etab_SQN ModeExercice Quali_salaire_base
							  salaire_base salaire_base_mois_complet CP Localite);
year=2024;
if missing(L_Contrat_SQN) then delete;
if input(substr(DebutCTT,1,4),4.) < 2019 then delete;
debut_dt = input(DebutCTT, yymmdd10.);
fin_dt = input(FinCTT, yymmdd10.);
if (fin_dt - debut_dt) < 31 then delete;
if h_force.find()^=0 then delete;
run;

data mylib.contract_2025;

if _N_=1 then do;
declare hash h_force(dataset:"ref_id");
h_force.defineKey("id_force");
h_force.defineDone();
end;

set mmo.MMO_2_2025_F17 (keep=id_force PcsEse L_Contrat_SQN DebutCTT FinCTT
							  PreDSN H_Etab_SQN ModeExercice Quali_salaire_base
							  salaire_base salaire_base_mois_complet CP Localite);
year=2025;
if missing(L_Contrat_SQN) then delete;
if input(substr(DebutCTT,1,4),4.) < 2019 then delete;
debut_dt = input(DebutCTT, yymmdd10.);
fin_dt = input(FinCTT, yymmdd10.);
if (fin_dt - debut_dt) < 31 then delete;
if h_force.find()^=0 then delete;
run;

/* Step 3: Keep only the latest iteration of the contract */

data mylib.contract_index;
	set mylib.contract_2025 (keep= L_Contrat_SQN year)
		mylib.contract_2024 (keep= L_Contrat_SQN year)
		mylib.contract_2023 (keep= L_Contrat_SQN year)
		mylib.contract_2022 (keep= L_Contrat_SQN year)
		mylib.contract_2021 (keep= L_Contrat_SQN year)
		mylib.contract_2020 (keep= L_Contrat_SQN year)
		mylib.contract_2019 (keep= L_Contrat_SQN year);
run;

proc sort data= mylib.contract_index;
by 	L_Contrat_SQN descending year;
run;

proc sort data= mylib.contract_index nodupkey;
by 	L_Contrat_SQN ;
run;

data ref_2019 ref_2020 ref_2021 ref_2022 ref_2023 ref_2024 ref_2025;
set mylib.contract_index;
if year=2019 then output ref_2019;
else if year=2020 then output ref_2020;
else if year=2021 then output ref_2021;
else if year=2022 then output ref_2022;
else if year=2023 then output ref_2023;
else if year=2024 then output ref_2024;
else if year=2025 then output ref_2025;
run;

proc datasets lib=mylib nolist;
delete contract_index;
quit;

/* Step 4: Pull full rows */

data mylib.fcontract_2025;
if _N_=1 then do;
declare hash h(dataset:"ref_2025");
h.defineKey("L_Contrat_SQN");
h.defineDone();
end;

set mylib.contract_2025;
if h.find() = 0 then output;
run;


data mylib.fcontract_2024;
if _N_=1 then do;
declare hash h(dataset:"ref_2024");
h.defineKey("L_Contrat_SQN");
h.defineDone();
end;

set mylib.contract_2024;
if h.find() = 0 then output;
run;

data mylib.fcontract_2023;
if _N_=1 then do;
declare hash h(dataset:"ref_2023");
h.defineKey("L_Contrat_SQN");
h.defineDone();
end;

set mylib.contract_2023;
if h.find() = 0 then output;
run;

data mylib.fcontract_2022;
if _N_=1 then do;
declare hash h(dataset:"ref_2022");
h.defineKey("L_Contrat_SQN");
h.defineDone();
end;

set mylib.contract_2022;
if h.find() = 0 then output;
run;

data mylib.fcontract_2021;
if _N_=1 then do;
declare hash h(dataset:"ref_2021");
h.defineKey("L_Contrat_SQN");
h.defineDone();
end;

set mylib.contract_2021;
if h.find() = 0 then output;
run;

data mylib.fcontract_2020;
if _N_=1 then do;
declare hash h(dataset:"ref_2020");
h.defineKey("L_Contrat_SQN");
h.defineDone();
end;

set mylib.contract_2020;
if h.find() = 0 then output;
run;

data mylib.fcontract_2019;
if _N_=1 then do;
declare hash h(dataset:"ref_2019");
h.defineKey("L_Contrat_SQN");
h.defineDone();
end;

set mylib.contract_2019;
if h.find() = 0 then output;
run;

/* Step 5: Bind and clean */

proc datasets lib=mylib nolist;
delete contract_2019 contract_2021 contract_2022 contract_2023 contract_2024 contract_2025 contract_2020;
quit;

data mylib.mmo_latest;
set mylib.fcontract_2019 mylib.fcontract_2020
	mylib.fcontract_2021 mylib.fcontract_2022
	mylib.fcontract_2023 mylib.fcontract_2024
	mylib.fcontract_2025;
run;

data mylib.mmo_latest;
set mylib.mmo_latest;
debut_dt = input(DebutCTT, yymmdd10.);
debut_dsn = input(PreDSN, yymmdd10.);
post_may2025 = (debut_dt >= '21MAY2025'd);
post_apr2025 = (debut_dt >= '01APR2025'd);
post_jan2024 = (debut_dt >= '29JAN2024'd);
post_mar2024 = (debut_dt >= '01MAR2024'd);
post_apr2021 = (debut_dt >= '01APR2021'd);

recent_dsn_may2025 = (debut_dsn >= '21MAY2023'd and debut_dsn < '21MAY2025'd);
recent_dsn_apr2025 = (debut_dsn >= '01APR2023'd and debut_dsn < '01APR2025'd);
recent_dsn_jan2024 = (debut_dsn >= '29JAN2022'd and debut_dsn < '29JAN2024'd);
recent_dsn_mar2024 = (debut_dsn >= '01MAR2022'd and debut_dsn < '01MAR2024'd);
recent_dsn_apr2021 = (debut_dsn >= '01APR2019'd and debut_dsn < '01APR2021'd);

if debut_dt =. then do;
	post_may2025 = 0;
	post_apr2025 = 0;
	post_jan2024 = 0;
	post_mar2024 = 0;
end;

if debut_dt =. then do;
	recent_dsn_may2025 = 0;
	recent_dsn_apr2025 = 0;
	recent_dsn_jan2024 = 0;
	recent_dsn_mar2024 = 0;
end;
run;

proc export data=mylib.mmo_latest
outfile="C:\Users\Public\Documents\Charagnoli\01 Intermediate Data\mmo_latest.csv"
dbms=csv replace;
run;
