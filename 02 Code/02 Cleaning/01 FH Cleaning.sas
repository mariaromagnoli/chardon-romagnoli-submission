/* This code: cleans FH for our purposes. */
libname fh "C:\Users\Public\Documents\Charagnoli\RawForCE";
libname mylib "C:\Users\Public\Documents\Charagnoli\01 Intermediate Data\FH";


/*Step 1: Restrictions */

proc sql;
create table de_tempo as 
select id_force, region, ndem, sexe, datnais, depcom,
					   nation, nivfor, diplome, datins, motins, contrat, 
					   temps, qualif, rome, exper, expeunit, motann, datann,
					   salmt, salunit
 
from fh.de_tempo
where datins >= '01JAN2019'd
and NATION in ("01", "27", "24", "26", "29", "19", "02", "91", "92", 
				"93", "94", "95", "96", "97", "98")
and id_force is not null
and id_force ne '';
quit;


/*Step 2: Variable creation */

data de_tempo;
set de_tempo;
sample1 = ifn(nation in ('01', '24', '27', '96'),1,0);
sample2 = ifn(nation in ('01', '24', '97', '98'),1,0);
sample3 = ifn(nation in ('01', '19', '26', '97', '98', '02'),1,0);
sample4 = ifn(nation in ('01', '29', '91', '92', '93', '94', '95'),1,0);
french = ifn(nation in ('01'), 1, 0);
eea = ifn(nation in ('27', '02', '19', '91','92','93','94','95','96','97','98'), 1, 0);
non_eea = ifn(nation in ('24','26','29'), 1, 0);
run;

proc freq data=de_tempo;
tables NIVFOR / nocum ;
run;

proc freq data=de_tempo;
where missing(NIVFOR);
tables NATION / nocum ;
run;

data de_tempo;
set de_tempo;
	select(NIVFOR);
	when ('AFS') formation = 0;
	when ('CP4') formation = 1;
	when ('CFG') formation = 2;
	when ('C3A') formation = 3;
	when ('C12') formation = 4;
	when ('NV5') formation = 5;
	when ('NV4') formation = 6;
	when ('NV3') formation = 7;
	when ('NV2') formation = 8;
	when ('NV1') formation = 9;
	otherwise formation = .;
	end;

run;

/*Step 3: Count spells per person*/
/* Some people have many spells, we want only demographic data though. Which information to keep? */

proc freq data=de_tempo noprint;
tables id_force / out= count_per_person(rename=(count=n_spells));
run;

proc sort data=de_tempo;
by id_force;
run;

proc sort data=count_per_person;
by id_force;
run;

data de_tempo2;
merge de_tempo count_per_person(keep= id_force n_spells);
by id_force;
run;


/*Step 4: Socio-demographics, one per person.*/

data unique_persons;
set de_tempo2;
where n_spells = 1;
drop n_spells;
run;

/* how frequent each combination is for each person + whats the latest */

proc sql;
create table modal_combos as
select *
from de_tempo2 
group by id_force
having n_spells > 1 and datins = max(datins);
quit;

data mylib.fh_latest;
set unique_persons modal_combos;
run;

proc export data= mylib.fh_latest
outfile="C:\\Users\\Public\\Documents\\Charagnoli\\01 Intermediate Data\\FH\\fh_latest.csv"
dbms=csv
replace;
run;

proc sql;
create table unique_ids as
select distinct id_force
from mylib.fh_latest;
quit;

proc export data= unique_ids
outfile="C:\\Users\\Public\\Documents\\Charagnoli\\01 Intermediate Data\\IDs\\unique_ids.csv"
dbms=csv
replace;
run;


proc freq data=mylib.fh_latest;
tables nation;
run;

proc freq data=mylib.fh_latest;
tables eea;
run;

proc freq data=mylib.fh_latest;
tables non_eea;
run;

proc freq data=mylib.fh_latest;
tables french;
run;