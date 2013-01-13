iets=1
while [ $iets -gt 0 ]
do
trap 'echo "fout" 1>&2' 0 1 2 5
perl -w -T check3<&0
iets=$?
echo $iets 1>&2
done
