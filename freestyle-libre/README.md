
# Disclaimer
This libre_app.pl script comes without warranty of any kind. Use them at your own risk. I assume no liability for the accuracy, correctness, completeness, or usefulness of any information provided by this site nor for any sort of damages using these scripts may cause.


# Usage Guide

#### Options

``` 
Usage: libre_app.pl [options]
  where options are: 
   --import <filename> --type <liapp|libre|libreview> [libre=reader data; libreview=cloud export - default]
   --export <filename>
   --db <dbname> 
   --months <year> 
   --weeks <numberofweeks> 
   --days <numberofdays> 
   --help usage

```

#### Example 1
``` 
./libre_app.pl 
Opening DB: libre-db.sqlite
Calculating A1C based on FreeStyle Libre CGM data...
 --- A1C for ALL data found in DB ---
BG data range:       2018-01-07 07:32 ---> 2020-01-08 14:54
BG data total:       731.31 days.
BG data count:       72934
BG data average:     108.24
BG data SD:          25.03  (SD ref range 10-26 for non-diabetes)
BG data CV:          23.12  (CV ref range 19-25 for non-diabetes)
Your predicted A1C:  5.40

```

#### Example 2
```
./libre_app.pl --weeks 7
Opening DB: libre-db.sqlite
Calculating A1C based on FreeStyle Libre CGM data...
 --- A1C for ALL data found in DB ---
BG data range:       2018-01-07 07:32 ---> 2020-01-08 14:54
BG data total:       731.31 days.
BG data count:       72934
BG data average:     108.24
BG data SD:          25.03  (SD ref range 10-26 for non-diabetes)
BG data CV:          23.12  (CV ref range 19-25 for non-diabetes)
Your predicted A1C:  5.40

--- A1C going back to 7 weeks from 01/08/2020  3:36:49 PM --- 
Week	Count	Average	SD	CV	A1C
7	601	120.75	21.49	17.80	5.83
6	493	122.77	22.58	18.40	5.90
5	520	118.12	24.70	20.91	5.74
4	535	112.23	24.07	21.45	5.54
3	527	111.03	22.77	20.51	5.50
2	577	114.22	22.86	20.02	5.61
1	513	118.58	25.36	21.39	5.76

```

#### Example 3
```
Opening DB: libre-db.sqlite
Calculating A1C based on FreeStyle Libre CGM data...
 --- A1C for ALL data found in DB ---
BG data range:       2018-01-07 07:32 ---> 2020-01-08 14:54
BG data total:       731.31 days.
BG data count:       72934
BG data average:     108.24
BG data SD:          25.03  (SD ref range 10-26 for non-diabetes)
BG data CV:          23.12  (CV ref range 19-25 for non-diabetes)
Your predicted A1C:  5.40

--- A1C going back to 7 days from 01/08/2020  3:37:11 PM --- 
Days	Count	Average	SD	CV	A1C
7	97	112.37	26.55	23.62	5.54
6	106	133.57	20.78	15.56	6.28
5	98	123.35	24.74	20.06	5.93
4	84	118.12	19.86	16.82	5.74
3	55	127.42	27.53	21.60	6.07
2	102	98.77	21.22	21.48	5.07
1	68	111.49	21.74	19.50	5.51

```
