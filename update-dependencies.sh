cd ./vendor/horde/
for d in */ ; do
    DIR=${d::-1}
    echo "$DIR"
    cd $DIR
    git remote remove origin
    git remote remove horde
    git remote add origin https://github.com/maintaina-com/$DIR.git
    git remote add horde https://github.com/horde/$DIR.git
    git fetch --all --tags
    git rebase horde/master
    git pull --rebase origin master
    git push origin master --tags
    cd ..
done
