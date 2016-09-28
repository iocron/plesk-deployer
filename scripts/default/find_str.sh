function find_str(){
	find . -exec grep -nH $1 . {} \; -print 2>/dev/null
}
