import unicodedata
from jaseci.actions.live_actions import jaseci_action  # step 1
from twilio.rest import Client

// account_sid = '' 
// auth_token = '' 
// client = Client(account_sid, auth_token) 


@jaseci_action(act_group=["twilio"], allow_remote=True)
def twilio_bot(message, phone_number, media):
    
    if (media != ''):
        file = ['https://drive.google.com/file/d/1BpEZGRwKg0-kMnLF2__f7ujf5pmDlpd1/view?usp=sharing']

        messages = client.messages.create( 
                                    from_='whatsapp:+',  
                                    # body=message,
                                    media_url=file,
                                    to=phone_number
                                ) 
        return messages
    else:
        messages = client.messages.create( 
                                    from_='whatsapp:+',  
                                    body=message,
                                    to=phone_number
                                ) 
        return messages


/*

Update
account_sid
auth_token
from_

https://www.twilio.com/console/projects/summary


and change .md to .py

*/
