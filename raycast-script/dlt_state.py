#!/usr/bin/env python3

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title DLT State Parser
# @raycast.mode fullOutput
# @raycast.packageName Developer Utils
#
# Optional parameters:
# @raycast.icon https://raw.githubusercontent.com/dlt-hub/dlt/devel/docs/website/static/img/dlt.png
# @raycast.argument1 { "type": "text", "placeholder": "Encrypted state" }

import base64
import zlib
import sys
import json

def decompress_data(data: str) -> str:
    try:
        base64_decoded = base64.b64decode(data, validate=True)
        decompressed_data = zlib.decompress(base64_decoded)
        decoded_str = decompressed_data.decode("utf-8")

        try:
            parsed_json = json.loads(decoded_str)
            return json.dumps(parsed_json, indent=2)
        except:
            return decoded_str

    except Exception as e:
        return f"Error in decompression: {str(e)}"

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Please provide the encrypted state data")
        sys.exit(1)

    encrypted_data = sys.argv[1]
    result = decompress_data(encrypted_data)
    print(result)
