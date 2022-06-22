# Kasa IoT bulb

### Commandline tool to turn on/off your Kasa (TPlink) IoT bulb

- #### /kasa.sh  
  Main script to turn on/off your Kasa bulb. This script is tested on macOS and Linux.

# Disclaimer
This kasa scripts uses TPlink/Kasa's unofficial/undocumented APIs and comes without warranty of any kind what so ever. You are free to use it at your own risk. I assume no liability for the accuracy, correctness, completeness, or usefulness of any information provided by this scripts nor for any sort of damages using these scripts may cause.

# Credits
https://docs.joshuatz.com/random/tp-link-kasa/ <br>
https://github.com/michalmoczynski/homeassistant-tplink-integration

# Setup
Create a directory called 'kasa' in your $HOME directory and create a file named '.kasarc' in that directory and include your kasa cloud account username and password as shown below. 

mkdir $HOME/kasa <br>
echo -e "user=\"your kasa username\"\npassword=\"your kasa password\"" > $HOME/kasa/.kasarc

# Usage

```
arul@lion$ ./kasa.sh -h

Usage: kasa.sh [options]
  -a <device_alias_list> ---> one or more comma separated alias name of the device(s) to enable [ex: bulb1,bulb2]
  -e <1|0>               ---> enable 1=on, 0=off
  -s                     ---> status
  -l                     ---> list all the Kasa IoT device alias names in your account
  -d                     ---> enable debugging output

example: kasa.sh -a "bulb1, bulb2" -e 1
```

# Sample run
```
# The example below turns the bulb named 'l1' to ON

arul@lion$  ./kasa.sh -a l1 -e 1 -d
[INFO] seting device (l1) to state: 1 ...
{
  "smartlife.iot.smartbulb.lightingservice": {
    "transition_light_state": {
      "on_off": 1,
      "mode": "normal",
      "hue": 0,
      "saturation": 0,
      "color_temp": 2700,
      "brightness": 100,
      "err_code": 0
    }
  }
}
[INFO] successfully set the state to 1 on device 'l1'!
```

```
# The example below shows all Kasa IoT devices in the network/cloud account (note: DeviceId is masked ofcourse)

arul@lion$ ./kasa.sh -l
[INFO] retrieve device list ...
[INFO] List of Kasa IoT devices found listed below:
	alias: p1; Model: KL110(US); Id: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	alias: l1; Model: LB100(US); Id: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	alias: bsl; Model: LB100(US); Id: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	alias: p2; Model: KL110(US); Id: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	alias: b2; Model: LB100(US); Id: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
	alias: doorbell; Model: KD110(US); Id: xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  ...
  ...

```
```
# The example below gets the status of device 'l1'

arul@lion$  ./kasa.sh -a l1 -s
Device 'l1' status is written to the file '/Users/arul/kasa/l1.json'
```
