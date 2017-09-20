#!/bin/sh

TMP_DIR='/tmp'

TMP_FILENAME="amazon_data_${BASHPID}"

TMP_FILEPATH=${TMP_DIR}'/'${TMP_FILENAME}

## score threshold
THRESHOLD=50

# parse args

usage_exit () {
	echo "Usage: $0 [-h] [-t THRESHOLD] [-v] [URL]" 1>&2
	echo
	echo "Options:" 1>&2
	echo "      h: this usage show." 1>&2
	echo "      t: notification threshold. the default threshold is 50." 1>&2
	echo "      v: verbose mode." 1>&2
	exit 1
}

check_digit () {
	if ! [[ $OPTARG =~ '[^1-9]' ]]; then
		THRESHOLD=$OPTARG
	fi
}

OPTIND=1

VERBOSE=0

while getopts "vht:" OPT
do
	case "${OPT}" in
		t) check_digit "${OPTARG}"
			;;
		h) usage_exit
			;;
		v) VERBOSE=1
			;;
		\?) usage_exit
			;;
	esac
done

shift $((OPTIND - 1))


if [ "${VERBOSE}" -eq 1 ]; then
	echo "SCRAPED DATE: `date`"
fi

if [ ! -z "$1" ]; then
	if [[ $1 =~ [\(http\)|\(https\)]\:// ]]; then
		curl -Lso- $1 > ${TMP_FILEPATH}
	else
		echo "URL ERROR." 1>&2
		exit 1
	fi
else
	cat /dev/stdin > ${TMP_FILEPATH}
fi

PRODUCT_TITLE=`cat ${TMP_FILEPATH} | xmllint --html --xpath 'string(//*[@id="title"]/span[1])' - 2> /dev/null | xargs`

if [ "${VERBOSE}" -eq 1 ]; then
	echo "PRODUCT: ${PRODUCT_TITLE}"
fi

DISCOUNT_RATE=`cat ${TMP_FILEPATH} | xmllint --html --xpath 'string(//*[contains(@class, "ebooks-price-savings")])' - 2> /dev/null | xargs | sed -e 's/^[^0-9]*\([1-9][,0-9]*\)[^0-9]*[(\|（]\([0-9]\+\)%[)\|）].*$/\2/g'`

if [ "${VERBOSE}" -eq 1 ]; then
	echo "EBOOK_DISCOUNT_RATE: ${DISCOUNT_RATE}"
fi

POINT_RATE=`cat ${TMP_FILEPATH} | xmllint --html --xpath 'string(//*[contains(@class, "loyalty-points")]/td[2])' - 2> /dev/null | xargs | sed -e 's/^[^0-9]*\([1-9][,0-9]*\)pt[^0-9]*[(\|（]\([0-9]\+\)%[)\|）].*$/\2/g'`

if [ "${VERBOSE}" -eq 1 ]; then
	echo "EBOOK_POINT_RATE: ${POINT_RATE}"
fi

if [ -z "$DISCOUNT_RATE" ]; then
	DISCOUNT_RATE=`cat ${TMP_FILEPATH} | xmllint --html --xpath 'string(//*[contains(text(), "OFF:")]/parent::*/descendant::*[contains(@class, "a-color-price")])' - 2> /dev/null | xargs | sed -e 's/^[^0-9]*\([1-9][,0-9]*\)[^0-9]*[(\|（]\([0-9]\+\)%[)\|）][^0-9]*$/\2/g'`

	if [ "${VERBOSE}" -eq 1 ]; then
		echo "DISCOUNT_RATE: ${DISCOUNT_RATE}"
	fi
fi

if [ -z "$POINT_RATE" ]; then
	POINT_RATE=`cat ${TMP_FILEPATH} | xmllint --html --xpath 'string(//*[contains(text(), "ポイント:")]/parent::*/descendant::*[contains(@class, "a-color-price")])' - 2> /dev/null | xargs | sed -e 's/^[^0-9]*\([1-9][,0-9]*\)pt[^0-9]*[(\|（]\([0-9]\+\)%[)\|）][^0-9]*$/\2/g'`

	if [ "${VERBOSE}" -eq 1 ]; then
		echo "POINT_RATE: ${POINT_RATE}"
	fi
fi

if [[ ${DISCOUNT_RATE} =~ [^0-9] ]] || [[ -z ${DISCOUNT_RATE} ]]; then
	DISCOUNT_RATE=0
fi

if [[ ${POINT_RATE} =~ [^0-9] ]] || [[ -z ${POINT_RATE} ]]; then
	POINT_RATE=0
fi

SCORE=$((DISCOUNT_RATE + POINT_RATE))

if ((${THRESHOLD} <= ${SCORE})); then
	notify-send -u critical "${PRODUCT_TITLE}" "Good Score:${SCORE} (Discount: ${DISCOUNT_RATE}% + Point: ${POINT_RATE}%)"
fi
