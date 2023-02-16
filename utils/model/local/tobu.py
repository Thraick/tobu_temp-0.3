from jaseci.actions.live_actions import jaseci_action
from datetime import datetime
from datetime import timedelta
from datetime import date
from dateutil.relativedelta import relativedelta
from PIL import Image
from PIL.ExifTags import TAGS
from GPSPhoto import gpsphoto
from geopy.geocoders import Nominatim
import requests


@jaseci_action(act_group=["tobu"], allow_remote=True)
def sort_date(
    list: list,
    key: str,
    date_format: str = "%Y-%m-%dT%H:%M:%S.%f",
    reverse: bool = False,
):
    list = sorted(
        list, key=lambda x: datetime.strptime(x[key], date_format), reverse=reverse
    )

    #print("HELLO")

    return list


@jaseci_action(act_group=["tobu"], allow_remote=True)
def phrase_to_date(phrase: str):
    today = date.today()
    datephrasefound = {}
    months = [
        "january",
        "february",
        "march",
        "april",
        "may",
        "june",
        "july",
        "august",
        "september",
        "october",
        "november",
        "december",
    ]
    weekdays = [
        "monday",
        "tuesday",
        "wednesday",
        "thursday",
        "friday",
        "saturday",
        "sunday",
    ]
    numbers = [
        "31",
        "30",
        "29",
        "28",
        "27",
        "26",
        "25",
        "24",
        "23",
        "22",
        "21",
        "20",
        "19",
        "18",
        "17",
        "16",
        "15",
        "14",
        "13",
        "12",
        "11",
        "10",
        "9",
        "8",
        "7",
        "6",
        "5",
        "4",
        "3",
        "2",
        "1",
    ]
    numberwords = [
        "thirty one",
        "thirty",
        "twenty nine",
        "twenty eight",
        "twenty seven",
        "twenty six",
        "twenty five",
        "twenty four",
        "twenty three",
        "twenty two",
        "twenty one",
        "twenty",
        "nineteen",
        "eighteen",
        "seventeen",
        "sixteen",
        "fifteen",
        "fourteen",
        "thirteen",
        "twelve",
        "eleven",
        "ten",
        "nine",
        "eight",
        "seven",
        "six",
        "five",
        "four",
        "three",
        "two",
        "one",
    ]
    slangs = ["month", "week", "day", "yesterday", "today"]
    wordsInPhrase = phrase.split()
    for month in months:
        capital = month.capitalize()
        if month in wordsInPhrase or capital in wordsInPhrase:
            datephrasefound["month"] = month
            break

    for day in weekdays:
        capital = day.capitalize()
        if day in wordsInPhrase or capital in wordsInPhrase:
            datephrasefound["weekDay"] = day
            break

    for (number, numberword) in zip(numbers, numberwords):
        if (
            number in wordsInPhrase
            or numberword in wordsInPhrase
            or phrase.find(number) != -1
        ):
            datephrasefound["number"] = number
            break

    for slang in slangs:
        if slang in wordsInPhrase:
            datephrasefound["slang"] = slang
            break

    if len(datephrasefound) == 1:
        if "month" in datephrasefound:
            firstoffset = (months.index(datephrasefound["month"]) + 1) - today.month
            if firstoffset < 0:
                rdate = today + relativedelta(months=firstoffset)
                return rdate.strftime("%Y-%m-%d")

            else:
                thisyear = today + relativedelta(months=firstoffset)
                rdate = thisyear - relativedelta(years=1)
                return rdate.strftime("%Y-%m-%d")

        elif "weekDay" in datephrasefound:
            firstoffset = (weekdays.index(datephrasefound["weekDay"])) - today.weekday()
            if firstoffset < 0:
                rdate = today + timedelta(days=firstoffset)
                return rdate.strftime("%Y-%m-%d")
            else:
                thisdate = today + timedelta(days=firstoffset)
                rdate = thisdate - timedelta(days=7)
                return rdate.strftime("%Y-%m-%d")

        elif "slang" in datephrasefound:
            if datephrasefound["slang"] == "week":
                rdate = today - timedelta(days=7)
                return rdate.strftime("%Y-%m-%d")
            elif datephrasefound["slang"] == "month":
                rdate = today - relativedelta(months=1)
                return rdate.strftime("%Y-%m-%d")
            elif (
                datephrasefound["slang"] == "day"
                or datephrasefound["slang"] == "yesterday"
            ):
                yesterday = today - timedelta(days=1)
                return yesterday.strftime("%Y-%m-%d")

            elif datephrasefound["slang"] == "today":
                return today.strftime("%Y-%m-%d")
        else:
            return today.strftime("%Y-%m-%d")
    if len(datephrasefound) == 2:
        if "month" in datephrasefound and "number" in datephrasefound:
            firstoffset = (months.index(datephrasefound["month"]) + 1) - today.month
            if firstoffset < 0:
                rdate = datetime(
                    2022,
                    (months.index(datephrasefound["month"]) + 1),
                    int(datephrasefound["number"]),
                )
                return rdate.strftime("%Y-%m-%d")

            else:
                rdate = datetime(
                    2021,
                    (months.index(datephrasefound["month"]) + 1),
                    int(datephrasefound["number"]),
                )
                return rdate.strftime("%Y-%m-%d")

        elif "weekDay" in datephrasefound and "number" in datephrasefound:
            rdate = today
            firstoffset = weekdays.index(datephrasefound["weekDay"]) - rdate.weekday()

            if firstoffset < 0:
                rdate = today + timedelta(days=firstoffset)
            else:
                thisdate = today + timedelta(days=firstoffset)
                rdate = thisdate - timedelta(days=7)
            days = 7 * (int(datephrasefound["number"]) - 1)
            rdate = rdate - timedelta(days=days)

            return rdate.strftime("%Y-%m-%d")

        elif "slang" in datephrasefound and "number" in datephrasefound:
            if datephrasefound["slang"] == "week":
                rdate = today - timedelta(days=7 * int(datephrasefound["number"]))
                return rdate.strftime("%Y-%m-%d")

            elif datephrasefound["slang"] == "month":
                rdate = today - relativedelta(months=1 * int(datephrasefound["number"]))
                return rdate.strftime("%Y-%m-%d")

            elif datephrasefound["slang"] == "day":
                rdate = today - timedelta(days=int(datephrasefound["number"]))
                return rdate.strftime("%Y-%m-%d")

        elif "slang" in datephrasefound and "month" in datephrasefound:
            firstoffset = (months.index(datephrasefound["month"]) + 1) - today.month
            if firstoffset < 0:
                rdate = today + relativedelta(months=firstoffset)
                return rdate.strftime("%Y-%m-%d")

            else:
                thisyear = today + relativedelta(months=firstoffset)
                rdate = thisyear - relativedelta(years=1)
                return rdate.strftime("%Y-%m-%d")

        else:
            return today.strftime("%Y-%m-%d")
    else:
        return today.strftime("%Y-%m-%d")


@jaseci_action(act_group=["tobu"], allow_remote=True)
def extract_exif_from_img(img: str):
    exifdataextracted = {
        "DateTime": None,
        "Location": None,
    }
    
    image = Image.open(requests.get(img, stream=True).raw)
    exifdata = image.getexif()
    for tagid in exifdata:
        tagname = TAGS.get(tagid, tagid)
        if tagname == "DateTime":
            date = exifdata.get(tagid)
            date = datetime.strptime(date, "%Y:%m:%d %H:%M:%S")
            exifdataextracted["DateTime"] = date.strftime("%Y-%m-%d")

            break
    data = gpsphoto.getGPSData(img)
    geolocator = Nominatim(user_agent="geoapiExercises")
    try:
        if data["Latitude"] != None and data["Longitude"] != None:
            lat = str(data["Latitude"])
            lon = str(data["Longitude"])
            location = geolocator.geocode(lat + "," + lon)
            exifdataextracted["Location"] = location.address

    except:
        return exifdataextracted

    return exifdataextracted


@jaseci_action(act_group=["tobu"], allow_remote=True)
def checkMemory(memory: str, found: bool, compare: str):
    if found:
        if memory == compare:
            return True
        else:
            return False
    else:
        return True


@jaseci_action(act_group=["tobu"], allow_remote=True)
def checkMemorylist(memory: str, found: bool, compares: list):
    if found:
        for compare in compares:
            print(compare)
            if compare.lower() not in memory and compare.upper() not in memory:
                return False

        return True
    else:
        return True


@jaseci_action(act_group=["tobu"], allow_remote=True)
def partialMatch(memory: str, found, compare: str):
    if found:
        terms = memory.split()
        if compare in terms:
            return True

        return False

    else:
        return True
