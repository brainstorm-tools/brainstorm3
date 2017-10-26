function check = isHG2
%check for HG2 update
check = ~verLessThan('matlab','8.4.0');
end
