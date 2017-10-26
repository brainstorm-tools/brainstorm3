function str = cell2json(s)
	str = '';
	for i =1:length(s)
		val = s{i};
		valstr = m2json(val);
		str = [str ', ' valstr];
	end
	str = str(3:end); % snip leading comma
	str = ['[' str ']'];
end