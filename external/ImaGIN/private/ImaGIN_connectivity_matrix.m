function CM=ImaGIN_connectivity_matrix(N)
% -=============================================================================
% This function is part of the ImaGIN software: 
% https://f-tract.eu/
%
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
%
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE AUTHORS
% DO NOT ASSUME ANY LIABILITY OR RESPONSIBILITY FOR ITS USE IN ANY CONTEXT.
%
% Copyright (c) 2000-2018 Inserm U1216
% =============================================================================-
%
% Authors: Olivier David

ncouple	= N*(N-1)/2;
if ncouple>0
    CM	= zeros(2,ncouple);
    cou	= 0;
    for ii	= 1:N-1
        j	= ii+1;
        cou	= cou+1;
        CM(1,cou)	= ii;
        CM(2,cou)	= j;
        while j < N
            j	= j+1;
            cou	= cou+1;
            CM(1,cou)	= ii;
            CM(2,cou)	= j;
        end
    end
else
    CM=[];
end
return
