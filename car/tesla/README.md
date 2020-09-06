# Tesla Tools

### Commandline tool to control/access your Tesla using Tesla's unofficial API.

- #### /tesla.sh  
  Main script to access various tesla commands. This script is tested on macOS and Linux.

- #### /tesla_token.sh
  Script to get/refresh a bearer token for your car to use with all API calls using the tesls.sh script above.

# Disclaimer
This tesla scripts use Tesla's unofficial APIs i.e. https://owner-api.teslamotors.com/api/1, and comes without warranty of any kind what so ever. You are free to use it at your own risk. I assume no liability for the accuracy, correctness, completeness, or usefulness of any information provided by this scripts nor for any sort of damages using these scripts may cause.

# Usage Guide

#### Options

``` 
./tesla.sh 
Usage: tesla.sh <id|state|wakeup|charge|climate|drive|honk|start|sentry|lock|unlock|location|update|log|light}>

```

#### Example 1
``` 
./tesla.sh wakeup
[INFO] attempting to wake up tesla...
[INFO] tesla should be awake now.

```

#### Example 2
``` 
./tesla.sh honk
[INFO] attempting to wake up tesla...
[INFO] tesla should be awake now.
[INFO] executing 'POST' on route: https://owner-api.teslamotors.com/api/1/vehicles/xxxxxxxxxxx/command/honk_horn ...
{
  "response": {
    "reason": "",
    "result": true
  }
}

```

#### Example 3
```
./tesla.sh lock
[INFO] attempting to wake up tesla...
[INFO] tesla should be awake now.
[INFO] executing 'POST' on route: https://owner-api.teslamotors.com/api/1/vehicles/xxxxxxxxxx/command/door_lock ...
{
  "response": {
    "reason": "",
    "result": true
  }
}

```
