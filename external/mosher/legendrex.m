function Pml = legendre(x,m,l);
% function Pml = legendre(x,m,l);
% P^m_l(x) 

% Copyright(c) 1994 John C. Mosher
% Los Alamos National Laboratory
% Group ESA-6, MS J580
% Los Alamos, NM 87545
% email: mosher@LANL.Gov

% March 17, 1994 author

% l >= |m| by definition

if(m < 0),			% conversion for negative m
  m = abs(m);
  c = (-1)^m * prod(1:(l-m))/prod(1:(l+m)); % (l-m)! / (l+m)!
else
  c = 1;
end

Pmm = (-1)^m * prod([1:2:(2*m)]) * (1 - x.^2).^(m/2);

if(m==l),
  Pml = c * Pmm; 
  return
end

Pmmp1 = (2*m+1) * x .* Pmm;

if((m+1)==l),
  Pml = c * Pmmp1;
  return;
end

Pm2 = Pmm;			% two back
Pm1 = Pmmp1;			% one back
for i = (m+2):l,
  Pml = ((2*i-1) * x .* Pm1 - (i + m - 1)*Pm2) / (i-m);
  Pm2 = Pm1;			% shift back one
  Pm1 = Pml;
end
Pml = c * Pml;

return
