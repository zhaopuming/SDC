//T compiles:yes
//T retval:0

int main()
{
	int i = 0;
	foreach(j; 1 .. 5)
	{
		i += j;
	}
	assert(i == 10);
	
	string str = "foobar";
	string str2 = "raboof";
	
	foreach(size_t j; 0 .. str.length)
	{
		assert(str[j] == str2[(str2.length - j) - 1]);
	}
	
	return 0;
}