#!/bin/bash
BASE_DIR=`pwd`;
GIT_DIR="/Users/gc/Temp/git_repo";
SVN_DIR="/Users/gc/Temp/svn_repo";
#You can select a specific branch here
GIT_REPO_BRANCH="development";
COMMIT_LOG_FILE="C:/commitlog.txt";
INTERMEDIATE_COMMIT="365e72575dfe3613928c368c2adf51678e877183";

# The SVN_AUTH variable can be used in case you need credentials to commit
#SVN_AUTH="--username guilherme.chapiewski@gmail.com --password XPTO"
SVN_AUTH="--username giovanni.esposito --password Password31!"

function svn_checkin {
	echo '... adding new files (svn)'
	for file in `svn st ${SVN_DIR} | awk -F" " '{print $1 "|" $2}'`; do
		fstatus=`echo $file | cut -d"|" -f1`
		fname=`echo $file | cut -d"|" -f2`

		if [ "$fstatus" == "?" ]; then
			if [[ "$fname" == *@* ]]; then
				svn add $fname@;
			else
				svn add $fname;
			fi
		fi
		if [ "$fstatus" == "!" ]; then
			if [[ "$fname" == *@* ]]; then
				svn rm $fname@;
			else
				svn rm $fname;
			fi
		fi
		if [ "$fstatus" == "~" ]; then
			rm -rf $fname;
			svn up $fname;
		fi
	done
	echo '... finished adding files (svn)'
}

function svn_commit {
	FIRST_ERROR=1;
	COMMIT_STATUS=1;
	echo "... committing to svn -> [$author]: $msg [$datetime]";
	while [ "$COMMIT_STATUS" == 1 ]; do
		#Original instruction
		#cd $SVN_DIR && svn $SVN_AUTH commit -m "[$author]: $msg [$datetime]" && cd $BASE_DIR;
		cd $SVN_DIR && svn $SVN_AUTH commit -m "[$author]: $msg [$datetime]"
		if [ $? -eq 0 ]; then
			echo '... committed to svn!'
			COMMIT_STATUS=0;
			FIRST_ERROR=1;
		else
			if [ $FIRST_ERROR -eq 1 ]; then
				cd $SVN_DIR && svn update;
				echo "SVN update performed."$'\r\n' >> $COMMIT_LOG_FILE;
				FIRST_ERROR=0;
			else
				COMMIT_STATUS=1;
				echo '!!! An error has occurred !!!'
				echo 'The import will be paused. Once the issue is solved press [Enter] for continuing.'
				read
			fi
		fi
		cd $BASE_DIR;
	done
}

#Script Menu
echo
echo "***********************************"
echo "*    git -> svn migration tool    *"
echo "***********************************"
echo "Current execution path: $BASE_DIR"
echo 
echo "Selected git repository path: $GIT_DIR"
echo 
echo "Selected svn repository path: $SVN_DIR"
echo 
echo "Selected branch: $GIT_REPO_BRANCH"
echo 
echo 
#STATE list
#0 -> the script is committing
#1 -> the script is looking for the selected commit

if [ -z "$INTERMEDIATE_COMMIT" ]; then
	STATE=0;
	echo "The script will start the import from the first commit";
	echo "Do you want to proceed? [Press ^C to quit or any other key to continue]";
	read;
else
	STATE=1;
	echo "The script will start the import from the commit $INTERMEDIATE_COMMIT";
	echo "Do you want to proceed? [Press ^C to quit or any other key to continue]";
	read;
fi 

echo "Do you want the program stopping after each commit? (Y/N)"
read STOP_MODE;

if [ "$STATE" == 1 ]; then
	echo "Looking for selected commit...";
fi

for commit in `cd $GIT_DIR && git rev-list --reverse $GIT_REPO_BRANCH && cd $BASE_DIR`; do 
	if [ "$STATE" == 1 ]; then
		echo "... current commit is $commit";
		if [ "$commit" == "$INTERMEDIATE_COMMIT" ]; then
			STATE=0;
			echo "commit $commit found";
		fi
	fi
	if [ "$STATE" == 0 ]; then
		echo "Starting committing $commit...";
		echo "Committing $commit..."$'\r\n' >> $COMMIT_LOG_FILE
		author=`cd ${GIT_DIR} && git log -n 1 --pretty=format:%an ${commit} && cd ${BASE_DIR}`;
		msg=`cd ${GIT_DIR} && git log -n 1 --pretty=format:%s ${commit} && cd ${BASE_DIR}`;
		# added datetime
		datetime=`cd ${GIT_DIR} && git log -n 1 --pretty=format:%ci ${commit} && cd ${BASE_DIR}`;
		
		# Checkout the current commit on git
		echo '... checking out commit on Git'
		cd $GIT_DIR && git checkout $commit && cd $BASE_DIR;
		
		# Delete everything from SVN and copy new files from Git
		echo '... copying files from git to svn folder'
		
		rm -rf $SVN_DIR/*;
		cp -prfu $GIT_DIR/* $SVN_DIR/;
		
		# Remove Git specific files from SVN
		echo '... removing git specific files from svn directory'
		for ignorefile in `find ${SVN_DIR} | grep .git | grep .gitignore`;
		do
			rm -rf $ignorefile;
		done
		
		# Add new files to SVN and commit
		svn_checkin && svn_commit;
		if [ "$STOP_MODE" == "Y" ]; then
			echo
			echo "Press Enter for proceeding to the following commit"
			read
		fi
	fi
done

