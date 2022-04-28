function [TET,Vtet,C]=hex2tet(varargin)

% function [TET,Vtet,C]=hex2tet(HEX,V,C,tetOpt)

%%

switch nargin
    case 2
        HEX=varargin{1};
        V=varargin{2};
        C=[];
        tetOpt=1;
    case 3
        HEX=varargin{1};
        V=varargin{2};
        C=varargin{3};
        tetOpt=1;
    case 4
        HEX=varargin{1};
        V=varargin{2};
        C=varargin{3};
        tetOpt=varargin{4};
    otherwise
        error('Wrong number of input arguments');
end

%%

C=C(:);
switch tetOpt
    case 1 %Add central node and cross side faces
        
        [F,~]=element2patch(HEX,C,'hex8');
        
        numV=size(V,1);
        numE=size(HEX,1);
        
        %The original vertices
        X=V(:,1); Y=V(:,2); Z=V(:,3);
        
        %The mid-element points
        if numE==1
            Vm=[mean(X(HEX),1) mean(Y(HEX),1) mean(Z(HEX),1)];
        else
            Vm=[mean(X(HEX),2) mean(Y(HEX),2) mean(Z(HEX),2)];
        end
        
        %The mid-face points
        Vf=[mean(X(F),2) mean(Y(F),2) mean(Z(F),2)];
        
        %TET point collection
        Vtet=[V; Vm; Vf];
        
        %Defining tetrahedral node list per hex element
        numV2=numV+numE+1;
        indAdd=reshape(numV2:(numV2+6*numE)-1,numE,6);        
        TET_set=[HEX (numV+1:numV+numE)' indAdd];

        TET_format=[14 13 9 10;...
                    12 14 9 10;...
                    15 12 9 10;...
                    13 15 9 10;...
                    %
                    13 14 9 11;...
                    14 12 9 11;...
                    12 15 9 11;...
                    15 13 9 11;...
                    %
                    1 10 12 15;...
                    2 10 14 12;...
                    3 10 13 14;...
                    4 10 15 13;...
                    %
                    5 11 15 12;...
                    6 11 12 14;...
                    7 11 14 13;...
                    8 11 13 15;...
                    %
                    1 2 12 10;...
                    2 3 14 10;...
                    3 4 13 10;...
                    4 1 15 10;...
                    %
                    5 6 11 12;...
                    6 7 11 14;...
                    7 8 11 13;...
                    8 5 11 15;...
                    %
                    1 5 15 12;...
                    2 6 12 14;...
                    3 7 14 13;...
                    4 8 13 15;...
                    ];
                
        %Reform TET_set as an nx4
        TET_set_reform1=TET_set(:,TET_format(:))';        
        TET_set_reform2=reshape(TET_set_reform1,size(TET_format,1),numel(TET_set_reform1)/size(TET_format,1))';
        TET=reshape(TET_set_reform2,4,numel(TET_set_reform2)/4)';
        
        %Fix color information
        C=repmat(C,size(TET_format,1),1);        
        
        %Removing double vertices
        [TET,Vtet]=mergeVertices(TET,Vtet);

    case 2 %Delaunay based 6 tetrahedron decomposition of cube applied to all
        HEX=HEX(:,[1 2 4 3 5 6 8 7]);
        tetInd =[5     1     2     3;...
            6     5     2     3;...
            6     7     5     3;...
            6     4     7     3;...
            6     2     4     3;...
            6     8     7     4];
        a=tetInd';
        a=a(:)';
        A=HEX(:,a);
        TET=reshape(A',4,6.*size(HEX,1))';
        if ~isempty(C)
            C=(ones(6,1)*C');
            C=C(:);
        end
        Vtet=V;
    case 3 %Same as 2 but flipped top to bottom
        
        %Switch top and bottom
        HEX=HEX(:,[8 7 5 6 4 3 1 2]);

        tetInd =[5     1     2     3;...
            6     5     2     3;...
            6     7     5     3;...
            6     4     7     3;...
            6     2     4     3;...
            6     8     7     4];
        a=tetInd';
        a=a(:)';
        A=HEX(:,a);
        TET=reshape(A',4,6.*size(HEX,1))';
        if ~isempty(C)
            C=(ones(6,1)*C');
            C=C(:);
        end
        Vtet=V;
    case 4 % 5 tetrahedron decomposition of cube
        tetInd=[1 8 6 5; 7 8 6 3; 2 1 3 6; 4 8 3 1; 6 3 8 1];      
        a=tetInd';
        a=a(:)';
        A=HEX(:,a);
        TET=reshape(A',4,5.*size(HEX,1))';
        if ~isempty(C)
            C=(ones(5,1)*C');
            C=C(:);
        end
        Vtet=V;
    case 5 %Same as 4 but flipped top to bottom
        %Switch top and bottom
        HEX=(HEX(:,[4 3 7 8 1 2 6 5 ]));

        tetInd=[1 8 6 5; 7 8 6 3; 2 1 3 6; 4 8 3 1; 6 3 8 1];
        a=tetInd';
        a=a(:)';
        A=HEX(:,a);
        TET=reshape(A',4,5.*size(HEX,1))';
        if ~isempty(C)
            C=(ones(5,1)*C');
            C=C(:);
        end
        Vtet=V;
    case 6 % tets for octet-truss lattice
         [F,~]=element2patch(HEX,C,'hex8');
        
        numV=size(V,1);
        numE=size(HEX,1);
        
        %The original vertices
        X=V(:,1); Y=V(:,2); Z=V(:,3);
        
        %The mid-element points
        if numE==1
            Vm=[mean(X(HEX),1) mean(Y(HEX),1) mean(Z(HEX),1)];
        else
            Vm=[mean(X(HEX),2) mean(Y(HEX),2) mean(Z(HEX),2)];
        end
        
        %The mid-face points
        Vf=[mean(X(F),2) mean(Y(F),2) mean(Z(F),2)];
        
        %TET point collection
        Vtet=[V; Vm; Vf];
        
        %Defining tetrahedral node list per hex element
        numV2=numV+numE+1;
        indAdd=reshape(numV2:(numV2+6*numE)-1,numE,6);        
        TET_set=[HEX (numV+1:numV+numE)' indAdd];

        TET_format=[...
%                     %
%                     14 13 9 10;...
%                     12 14 9 10;...
%                     15 12 9 10;...
%                     13 15 9 10;...
%                     %
%                     13 14 9 11;...
%                     14 12 9 11;...
%                     12 15 9 11;...
%                     15 13 9 11;...
                    %
                    1 10 12 15;...
                    2 10 14 12;...
                    3 10 13 14;...
                    4 10 15 13;...
                    %
                    5 11 15 12;...
                    6 11 12 14;...
                    7 11 14 13;...
                    8 11 13 15;...

                    %
                    1 5 15 12;...
                    2 6 12 14;...
                    3 7 14 13;...
                    4 8 13 15;...
                    ];
                
        %Reform TET_set as an nx4
        TET_set_reform1=TET_set(:,TET_format(:))';        
        TET_set_reform2=reshape(TET_set_reform1,size(TET_format,1),numel(TET_set_reform1)/size(TET_format,1))';
        TET=reshape(TET_set_reform2,4,numel(TET_set_reform2)/4)';
        
        %Fix color information
        C=repmat(C,size(TET_format,1),1);        
        
        %Removing double vertices
        [TET,Vtet]=mergeVertices(TET,Vtet);
end

TET=TET(:,[1 2 4 3]); %Invert

 
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
