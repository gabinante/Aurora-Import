printf "Please enter MySQL Host [localhost] : "
read MYSQL_HOST
if [ ! $MYSQL_HOST ]; then
        MYSQL_HOST="localhost"
fi

printf "Please enter MySQL User [root] : "
read MYSQL_USER
if [ ! $MYSQL_USER ]; then
        MYSQL_USER="root"
fi

printf "Please enter MySQL Pass : "
read -s MYSQL_PASS
echo ""

printf "Please enter MySQL Port [3306] : "
read MYSQL_PORT
if [ ! $MYSQL_PORT ]; then
	MYSQL_PORT=3306
fi
#WARNING! This will replace the data in the selected database!
printf "Please enter database to import data into [database] : "
read DATABASE
if [ ! $DATABASE ]; then
        DATABASE="database"
fi

printf "Data path [/var/lib/mysql/dump] : "
read TARGET
if [ ! $TARGET ]; then
        TARGET="/var/lib/mysql/dump"
fi

printf "Import Threads [3] : "
read THREADS
if [ ! $THREADS ]; then
        THREADS=3
fi
if [ $THREADS -gt 10 ]; then
	echo "More than 10 threads is not advised.  Please choose less than or equal to 10"
	`rm -rf ./.my.multi.cnf`
        exit 1
fi
#Create temporary password file. Sorry, can't think of a more secure way to do this!
echo ""
echo "Attempting connection to $MYSQL_HOST using $MYSQL_USER on $MYSQL_PORT.  Creating temporary pass file .my.multi.cnf"
echo ""

echo "[client]" > ./.my.multi.cnf
echo "user=$MYSQL_USER" >> ./.my.multi.cnf
echo "password='$MYSQL_PASS'" >> ./.my.multi.cnf
echo "port=$MYSQL_PORT" >> ./.my.multi.cnf
#Check accessibility & permissions in DB
MYSQLDBCHECK=`mysql --defaults-file=./.my.multi.cnf -B -N -h $MYSQL_HOST -e "SHOW DATABASES" | grep $DATABASE | wc -l`
if [ $MYSQLDBCHECK -ge 1 ]; then
		echo "MySQL connection passed and $DATABASE found!"
	else
        	echo "MySQL connection failed, or $DATABASE not found!"
		`rm -rf ./.my.multi.cnf`
        	exit 1
fi
echo ""

echo "Checking for $TARGET"
if [ ! -d $TARGET ]; then
	echo "Directory does not exist"
	`rm -rf ./.my.multi.cnf`
	exit 1
else
	echo "Target directory $TARGET found"
fi
echo ""
#Point of no return
printf "Are you sure you want to start the import now? [y/n] : "
read CONFIRM
if [ $CONFIRM == "y" ] || [ $CONFIRM == "Y" ] || [ $CONFIRM == "yes"] || [ $CONFIRM == "Yes"]; then
        echo "Starting import now"
else
	echo "Yes was not chosen.  Exiting."
	`rm -rf ./.my.multi.cnf`
	exit 1
fi

`echo "Starting Import" > /tmp/aurora_import.log`
`echo date >> /tmp/aurora_import.log`
#Truncates table (drops all data but keeps table structure), followed by load data
for f in `ls -1 $TARGET`; do
	echo "  Processing $f"
	TABLE=`echo $f | cut -f1 -d.`
	echo "    Truncating Table : $TABLE"
	`mysql --defaults-file=./.my.multi.cnf -h $MYSQL_HOST -vv $DATABASE -e "TRUNCATE TABLE $TABLE;" >> /tmp/aurora_import.log`
	`mysql --defaults-file=./.my.multi.cnf -h $MYSQL_HOST -vv $DATABASE -e "LOAD DATA LOCAL INFILE '$TARGET/$f' INTO TABLE $TABLE FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '\"' lines terminated by '\\n';" >> /tmp/aurora_import.log &`
	RUNNING_THREADS=`ps aux | grep mysql | grep csv | wc -l`
	echo "Running Threads $RUNNING_THREADS"
	while [ $RUNNING_THREADS -ge $THREADS ]; do
		sleep 5
		RUNNING_THREADS=`ps aux | grep mysql | grep csv | wc -l`
	done
done

#Delete credential file. Your data is safe, I promise!
`rm -rf ./.my.multi.cnf`
