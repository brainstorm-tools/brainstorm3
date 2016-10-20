function Y = spherharm(theta,phi,l,m);
% function Y = spherharm(theta,phi,l,m);

mp = abs(m);			% positive m

Y = sqrt((2*l + 1)/(4*pi) * (prod(1:(l-mp))/prod(1:(l+mp)))) * ...
    legendrex(cos(theta),mp,l) .* exp(sqrt(-1)*mp*phi);

if(m < 0),
  Y = (-1)^mp * conj(Y);
end
return
