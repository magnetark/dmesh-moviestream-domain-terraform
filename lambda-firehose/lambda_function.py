# ------
# LAMBDA
# zip code.zip lambda_function.py
## aws s3 cp code.zip s3://<s3-bucet-name>/v1/code.zip
#
# DATA SAMPLE
# {'records':[
#     {
#     	'recordId': '49633053771318725182731865403139531158769665947818000386000000',
#     	'approximateArrivalTimestamp': 1662499846395,
#     	'data': {  ---> payload
#           "data":{
#               "index":138756,
#               "userId":6550,
#               "movieId":98004
#           },"metadata":{
#               "timestamp":"2022-09-06T21:30:46.390049Z",
#               "record-type":"data",
#               "operation":"load",
#               "partition-key-type":"primary-key",
#               "partition-key-value":"public.tags.138756",
#               "schema-name":"public",
#               "table-name":"tags"
#           }
#       },
#     	'kinesisRecordMetadata': {
#     		'sequenceNumber': '49633053771318725182731865403139531158769665947818000386',
#     		'subsequenceNumber': 0,
#     		'partitionKey': 'public.tags.138756',
#     		'shardId': 'shardId-000000000000',
#     		'approximateArrivalTimestamp': 1662499846395
#     	}
#     },
#     {
#       "metadata":{
#           "timestamp":"2022-09-06T22:04:34.323689Z",
#           "record-type":"control",
#           "operation":"create-table",
#           "partition-key-type":"task-id",
#           "partition-key-value":"AACCCNFDCFUWN4MZBTBMA4TICX7L7FIYXZPGMIQ",
#           "schema-name":"",
#           "table-name":"awsdms_apply_exceptions"
#        }
#      }
# ]}

import json
import base64
import datetime

def lambda_handler(event, context):
    firehose_records_output = {'records': []}

    for record in event['records']:
        try:
            payload = json.loads(base64.b64decode(record['data']))
            event_timestamp = datetime.datetime.strptime(payload['metadata']["timestamp"], '%Y-%m-%dT%H:%M:%S.%fZ')
            partition_keys = {
                "schema":payload['metadata']["schema-name"],
                "table":payload['metadata']["table-name"],
                "year": event_timestamp.strftime('%Y'),
                "month": event_timestamp.strftime('%m'),
                "date": event_timestamp.strftime('%d'),
                "hour": event_timestamp.strftime('%H'),
                "minute": event_timestamp.strftime('%M')
            }
            #event_timestamp = datetime.datetime.fromtimestamp(record['approximateArrivalTimestamp'] / 1000.0)

            record_output = {
                'recordId': record['recordId'],
                'data': record['data'],
                'result': 'Ok',
                'metadata': { 
                    'partitionKeys': partition_keys 
                }
            }
        except Exception as e:
            record["error"] = e
            record_output = {
                'data':record,
                'result': 'Ok',
                'metadata': { 
                    'partitionKeys': {
                        "partitionKey":"unhandled-events"
                    } 
                }
            }
        firehose_records_output['records'].append(record_output)

    return firehose_records_output
