# Usage Guide

#### Options

``` 
./libre_app.pl --help
Usage: libre_app.pl [options]
  where options are: 
   --import <filename> --type <liapp|libre>
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
BG data range:       2018-01-07 07:32 ---> 2019-01-26 13:48
BG data total:       384.26 days.
BG data count:       39302
BG data average:     103.62
BG data stddev:      23.82
Your predicted A1C:  5.24
```

#### Example 2
```
./libre_app.pl --weeks 7
Opening DB: libre-db.sqlite
Calculating A1C based on FreeStyle Libre CGM data...
 --- A1C for ALL data found in DB ---
BG data range:       2018-01-07 07:32 ---> 2019-01-26 13:48
BG data total:       384.26 days.
BG data count:       39302
BG data average:     103.62
BG data stddev:      23.82
Your predicted A1C:  5.24

--- A1C going back to 7 weeks from 01/26/2019  1:56:19 PM --- 
Week	Count	Average	SD	A1C
7	603	98.99	22.45	5.08
6	491	96.32	15.51	4.98
5	445	102.81	17.59	5.21
4	443	105.17	17.66	5.29
3	533	112.04	21.11	5.53
2	528	109.92	20.88	5.46
1	418	129.45	31.07	6.14
```

#### Example 3
```
./libre_app.pl --days 7
Opening DB: libre-db.sqlite
Calculating A1C based on FreeStyle Libre CGM data...
 --- A1C for ALL data found in DB ---
BG data range:       2018-01-07 07:32 ---> 2019-01-26 13:48
BG data total:       384.26 days.
BG data count:       39302
BG data average:     103.62
BG data stddev:      23.82
Your predicted A1C:  5.24

--- A1C going back to 7 days from 01/26/2019  1:57:10 PM --- 
Days	Count	Average	SD	A1C
7	91	106.90	17.72	5.35
6	96	109.72	18.01	5.45
5	36	111.00	10.15	5.49
4	50	117.90	35.45	5.74
3	85	137.13	35.92	6.41
2	91	147.87	28.35	6.78
1	60	142.92	19.64	6.61
```
