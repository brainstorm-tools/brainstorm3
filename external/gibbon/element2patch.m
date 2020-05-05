function [varargout]=element2patch(varargin)

% function [F,C,CF]=element2patch(E,C,elementType);
% ------------------------------------------------------------------------
% This function generates faces F for the input elements E such that the
% elements can be visualized using patch graphics. Color data C on the
% elements can also be provided which will be used to define the colors C
% for the faces. A large array of element types are supported ranging from
% the trivial triangular and quadrilateral faces (linear and quadratic) to
% linear and quadratic hexahedral and tetrahedral elements. 
% 
%
% Kevin Mattheus Moerman
% gibbon.toolbox@gmail.com
% 
% 2014/10/22
%------------------------------------------------------------------------

%% PARSE INPUT

switch nargin
    case 1
        E=varargin{1};
        C=[1:1:size(E,1)]'; %Element based colors
        elementType=[];
    case 2
        E=varargin{1};
        C=varargin{2};
        elementType=[];
    case 3
        E=varargin{1};
        C=varargin{2};
        elementType=varargin{3};
    otherwise
        error('Wrong number of inputs');
end

numNodes=size(E,2);

if isempty(elementType) %have to assume defaults    
    switch numNodes             
        case 8 %Hexahedral elements
            elementType='hex8';            
        case 20 %Hexahedral elements
            elementType='hex20';
        case 4 %Linear tets
            elementType='tet4';
        case 10 %Quadratic tets
            elementType='tet10';
        case 6 %Quadratic triangles
            elementType='tri6';
        case 3
            elementType='tri3';
        otherwise            
            elementType='unknown';
    end    
%     disp([elementType,' elements assumed, for other elements please specify elementType']);
end

%%

switch elementType
    case 'penta6'
        F_tri=[E(:,[3 2 1]);... %face 1
           E(:,[4 5 6]);... %face 2
            ]; 
        F_quad=[E(:,[1 2 5 4]);... %face 3
                E(:,[2 3 6 5]);... %face 4
                E(:,[3 1 4 6]);... %face 5
            ];
        F={F_tri,F_quad};
        
        C_tri=repmat(C,2,1);
        C_quad=repmat(C,3,1);
        C={C_tri,C_quad};
        
        CF=C;
    case 'tri3' %Linear triangles
        F=E;
        C=C;
        CF=C;
    case 'tri6' %Quadratic triangles
        F=E(:,[1 4 2 5 3 6]);            
        C=C; 
        CF=C;
    case 'quad4' %Linear quadrangles
        F=E;
        C=C;
        CF=C;
    case 'quad8' %Quadratic quadrangles        
         F=E(:,[1 5 2 6 3 7 4 8]); 
         C=C;
         CF=C;
    case 'tet4' %Linear tets
        F=[E(:,[2 1 3]);... %face 1 2 3
            E(:,[1 2 4]);... %face 1 2 4
            E(:,[2 3 4]);... %face 2 3 4
            E(:,[3 1 4])];   %face 1 3 4
        C=repmat(C,4,1); %Replicate color data        
        CF=repmat(1:1:4,[size(E,1) 1]); 
        CF=CF(:);
    case 'tet10' %Quadratic tets
         F=[E(:,[2 5 1 7  3 6 ]);... %face 1 2 3
            E(:,[1 5 2 9  4 8 ]);... %face 1 2 4
            E(:,[2 6 3 10 4 9 ]);... %face 2 3 4
            E(:,[3 7 1 8  4 10])];   %face 1 3 4        
%         F=fliplr(F);
        C=repmat(C,4,1); %Replicate color data
        CF=repmat(1:1:4,[size(E,1) 1]); 
        CF=CF(:);
    case 'hex8' %Hexahedral elements
        F =[E(:,[4 3 2 1]);... %top
            E(:,[5 6 7 8]);... %bottom
            E(:,[1 2 6 5]);... %side 1
            E(:,[3 4 8 7]);... %side 2
            E(:,[2 3 7 6]);... %front
            E(:,[5 8 4 1]);]; %back                
        C=repmat(C,6,1);
        CF=repmat(1:1:6,[size(E,1) 1]); 
        CF=CF(:);
    case 'hex20' %Hexahedral elements
        F =[E(:,[4  11 3  10 2  9  1 12]);... %top
            E(:,[5  13 6  14 7  15 8 16]);... %bottom
            E(:,[1  9  2  18 6  13 5 17]);... %side 1
            E(:,[3  11 4  20 8  15 7 19]);... %side 2
            E(:,[2  10 3  19 7  14 6 18]);... %front
            E(:,[5  16 8  20 4  12 1 17]);]; %back
        C=repmat(C,6,1);        
        CF=repmat(1:1:6,[size(E,1) 1]); 
        CF=CF(:);
    case 'unknown'
        F=E;
        C=C;
        CF=C;
    otherwise
        error([elementType,' is not a known element type']);
end

%% Compose output
varargout{1}=F; 
varargout{2}=C; 
varargout{3}=CF; 

end
 
%% 
% _*GIBBON footer text*_ 
% 
% License: <https://github.com/gibbonCode/GIBBON/blob/master/LICENSE>
% 
% GIBBON: The Geometry and Image-based Bioengineering add-On. A toolbox for
% image segmentation, image-based modeling, meshing, and finite element
% analysis.
% 
% Copyright (C) 2019  Kevin Mattheus Moerman
% 
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
