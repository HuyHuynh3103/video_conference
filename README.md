# Video_conference_demo

## How to Run ##

Install package
```bash
flutter pub get
```

Run application
```bash
flutter run
```

## request token ##
**endpoint structure**
```bash
https://agora-token-service-production-61a1.up.railway.app/rtc/CHANNEL_NAME/:role/:token_type/:uid/?expiry=EXPIRY_TIME
```
token response
``` json
{"rtcToken":" "} 
```

Agora documentation: [Live Stream Flutter](https://docs.agora.io/en/interactive-live-streaming/develop/authentication-workflow?platform=flutter)
