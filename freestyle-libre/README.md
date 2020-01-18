
# Disclaimer
This libre_app.pl script comes without warranty of any kind. Use it at your own risk. I assume no liability for the accuracy, correctness, completeness, or usefulness of any information provided by this scripts nor for any sort of damages using these scripts may cause.


# Usage Guide

#### Options

``` 
Usage: libre_app.pl [options]
  where options are: 
   --import <filename> --type <liapp|libre|libreview> [libre=reader data; libreview=cloud export - default]
   --export <filename>
   --db <dbname> 
   --months <number of months> 
   --weeks <number of weeks> 
   --days <number of days> 
   --help usage
   --debug 1 print debug message

```

#### Example 1
``` 
./libre_app.pl --days 14
Opening DB: libre-db.sqlite
Calculating A1C based on FreeStyle Libre CGM data...
--- A1C going back to 14 days from 01/18/2020 11:11:32 AM --- 
Days	Count	Average	SD	CV	A1C
14	98	116.93	20.45	17.49	5.70
13	49	130.39	27.03	20.73	6.17
12	88	99.42	20.79	20.92	5.09
11	104	112.96	25.02	22.15	5.56
10	102	104.34	17.46	16.73	5.26
9	109	103.58	14.35	13.86	5.24
8	80	100.60	19.05	18.94	5.13
7	99	102.99	22.25	21.61	5.22
6	92	109.39	12.26	11.21	5.44
5	97	105.68	25.39	24.03	5.31
4	84	102.27	19.60	19.16	5.19
3	92	105.38	29.67	28.15	5.30
2	96	103.99	22.03	21.18	5.25
1	61	99.89	18.84	18.86	5.11

--- A1C for the entire period in the last 14 days --- 
Count	Average	SD	CV	A1C
1251	106.47	22.30	20.94	5.34
```

#### Example 2
```
./libre_app.pl --weeks 4
Opening DB: libre-db.sqlite
Calculating A1C based on FreeStyle Libre CGM data...
--- A1C going back to 4 weeks from 01/18/2020 11:11:41 AM --- 
Week	Count	Average	SD	CV	A1C
4	557	116.08	22.55	19.43	5.67
3	552	119.59	24.16	20.20	5.79
2	582	104.25	20.47	19.64	5.26
1	522	104.75	22.30	21.29	5.28

--- A1C for the entire period in the last 4 weeks --- 
Count	Average	SD	CV	A1C
2213	111.17	23.38	21.03	5.50
```

#### Example 3
```
./libre_app.pl --months 3
Opening DB: libre-db.sqlite
Calculating A1C based on FreeStyle Libre CGM data...
--- A1C by month starting with 3 months before to current --- 
Months	Count	Average	SD	CV	A1C
3	2570	108.94	24.54	22.52	5.42
2	2564	118.37	23.50	19.85	5.75
1	2737	111.02	23.43	21.11	5.50

--- A1C for the entire period in the last 3 months --- 
Count	Average	SD	CV	A1C
7871	112.73	24.15	21.42	5.56
```
