# iXForms
Swift iOS ODK-compatible XForms client

## Widget Support

XLSForm | XForm | Appearance | Params | Status | Comment
--|--|--|--|--|--
text | string | | | :heavy_check_mark: |
| | | numbers | | :heavy_check_mark: |
| | | url | | :heavy_check_mark: |
| | | multiline | | |
| | | ex: (external) | | :x: |
| | | printer: | | :x: |
note | string | | readonly=true() | :heavy_check_mark: | note is just a read-only string control
integer | int | | | :heavy_check_mark: |
| | | thousands-sep | | :heavy_check_mark: |
| | | ex: (external) | | :x: |
decimal | decimal | | | :heavy_check_mark: |
| | | ex: (external ) | | :x: |
| | | bearing | | :heavy_check_mark: | compass widget
range | range | | | :heavy_check_mark: | both integer and decimal supported
| | | vertical | | :question: | displayed as horizontal...
| | | picker | | :heavy_check_mark: |
| | | rating | | :heavy_check_mark: | 
image | binary ||| :heavy_check_mark: |
| | | new | | :heavy_check_mark: | 
| | | selfie | | :question: | auto-selects selfie camera, but can still manually switch to front camera
| | | ex: (external) | | :x: |
| | | draw | | :heavy_check_mark: |
| | | annotate | | :question: | currently only support cropping (not yet draw annotations)
| | | signature | | :heavy_check_mark: |
barcode | barcode ||| :heavy_check_mark: |
audio | binary ||| :x: |
video | binary ||| :heavy_check_mark: | picker needs work...
file | binary ||| :x: |
date | date ||| :heavy_check_mark: |
| | | no-calendar || :heavy_check_mark: | same as default
| | | month-year || :heavy_check_mark: | UIDatePicker still shows day (but not saved)
| | | year || :heavy_check_mark: | UIDatePicker still shows day and month (but not saved)
time | time ||| :heavy_check_mark: |
dateTime | dateTime ||| :heavy_check_mark: |
| | | no-calendar || :heavy_check_mark: | same as default
| | | ethoipian || :x: |
| | | coptic || :x: |
| | | islamic || :x: |
| | | bikram-sambat || :x: |
| | | myanmar || :x: |
| | | persian || :x: |
geopoint | geopoint ||| :heavy_check_mark: |
| | | maps || :heavy_check_mark: | same as default
| | | placement-map || :heavy_check_mark: |
geotrace | geotrace ||| :x: |
geoshape | geoshape ||| :x: |
osm | binary ||| :x: |
select_one | select1 ||| :heavy_check_mark: |
select_multiple | select ||| :heavy_check_mark: |
rank |||| :x: |
trigger | trigger ||| :heavy_check_mark: |

## Other Feature Support

XLSForm | XForm  | Status | Comment
--|--|--|--
relevant | | :x: |
constraint | | :x: |
constraint_message | | :x: |
calculation | | :x: |
choice_filter | | :x: |
default | | :x: |
note | hint | :heavy_check_mark: |
itext | | :x: |
begin_group | group | :heavy_check_mark: | top-level groups (form sections) supported. nested groups (subpages) not yet supported
field-list | | :x: |
repeat | | :x: |


## Supported XPath Functions
