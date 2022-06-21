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
arul@lion$ kasa.sh -h

Usage: kasa.sh [options]
  -a <device_alias> ---> the alias name of the device [ex: mybulb1]
  -s                ---> status
  -e <1|0>          ---> enable 1=on, 0=off

example: kasa.sh -a mybulb1 -e 1
```

# Sample run
```
## turn on your bulb named 'l1'

arul@lion$ ./kasa.sh -a l1 -e 1
[INFO] retrieve device list ...
[INFO] seting device (l1) to state: 1 ...
{
  "error_code": 0,
  "result": {
    "responseData": "{\"smartlife.iot.smartbulb.lightingservice\":{\"transition_light_state\":{\"on_off\":1,\"mode\":\"normal\",\"hue\":0,\"saturation\":0,\"color_temp\":2700,\"brightness\":100,\"err_code\":0}}}"
  }
}
[INFO] successfully set the state to 1 on device 'l1'!

```
