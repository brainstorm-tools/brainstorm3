function [Points_Moved,M]=ICP_finite(Points_Static, Points_Moving, Options)
%  This function ICP_FINITE is an kind of Iterative Closest Point
%  registration algorithm for point clouds (vertice data) using finite
%  difference methods.
%
%  Normal ICP  solves translation and rotation with analytical equations.
%  By using finite difference this function can also solve resize and shear.
%
%  This function is first sorts the static points into a grid of
%  overlapping blocks. The block nearest to a moving point will contain
%  its closest static point, thus the grid allows faster registration.
%
%  [Points_Moved,M]=ICP_finite(Points_Static, Points_Moving, Options);
%
%  inputs,
%       Points_Static : An N x 3 array with XYZ points which describe the
%                           registration target
%       Points_Moving : An M x 3 array with XYZ points which will move and
%                           be registered on the static points.
%       Options : A struct with registration options:
%           Options.Registration: 'Rigid', Translation and Rotation (default)
%                                 'Size', Rigid + Resize
%                                 'Affine', Translation, Rotation, Resize
%                                               and Shear.
%           Options.TolX: Registration Position Tollerance, default is the
%              largest side of a volume containing the points divided by 1000
%           Options.TolP: Allowed tollerance on distance error default
%              0.001 (Range [0 1])
%           Options.Optimizer : optimizer used, 'fminlbfgs' (default)
%             ,'fminsearch' and 'lsqnonlin'.
%           Options.Verbose : if true display registration information (default)
%
%  outputs,
%       Points_Moved : An M x 3 array with the register moving points
%       M : The transformation matrix. Can be used with function movepoints
%               to transform other arrays with 3D points.
%
%  example,
%   % Make Static Points
%   npoinst=10000;
%   x=rand(npoinst,1)*100-50; y=rand(npoinst,1)*100-50; z=sqrt(x.^2+y.^2);
%   Points_Static=[x y z];
%
%   % Make Moving Points
%   x=rand(npoinst-100,1)*100-50; y=rand(npoinst-100,1)*100-50; z=sqrt(x.^2+y.^2);
%   Points_Moving=[x y z];
%   M=[1.4 -0.1710 0.1736 10.0000; 0.1795 0.9832 -0.0344 5.0000; -0.1648 0.0645 0.9842 20.0000; 0 0 0 1.0000]
%   Points_Moving=movepoints(M,Points_Moving);
%
%   % Register the points
%   [Points_Moved,M]=ICP_finite(Points_Static, Points_Moving, struct('Registration','Size'));
%
%   % Show start
%   figure, hold on;
%   plot3(Points_Static(:,1),Points_Static(:,2),Points_Static(:,3),'b*');
%   plot3(Points_Moving(:,1),Points_Moving(:,2),Points_Moving(:,3),'m*');
%   view(3);
%   % Show result
%   figure, hold on;
%   plot3(Points_Static(:,1),Points_Static(:,2),Points_Static(:,3),'b*');
%   plot3(Points_Moved(:,1),Points_Moved(:,2),Points_Moved(:,3),'m*');
%   view(3);
%
% Function is written by D.Kroon University of Twente (May 2009)

% Display registration process


defaultoptions=struct('Registration','Rigid','TolX',0.001,'TolP',0.001,'Optimizer','fminlbfgs','Verbose', true);
if(~exist('Options','var')),
    Options=defaultoptions;
else
    tags = fieldnames(defaultoptions);
    for i=1:length(tags)
        if(~isfield(Options,tags{i})),  Options.(tags{i})=defaultoptions.(tags{i}); end
    end
    if(length(tags)~=length(fieldnames(Options))),
        warning('register_images:unknownoption','unknown options found');
    end
end

% Process Inputs
if(size(Points_Static,2)~=3),
    error('ICP_finite:inputs','Points Static is not a m x 3 matrix');
end
if(size(Points_Moving,2)~=3),
    error('ICP_finite:inputs','Points Moving is not a m x 3 matrix');
end

% Inputs array must be double
Points_Static=double(Points_Static);
Points_Moving=double(Points_Moving);

% Make Optimizer name lower case
Options.Optimizer=lower(Options.Optimizer);

% Set initial values depending on registration type
switch (lower(Options.Registration(1)))
    case 'r',
        if(Options.Verbose), disp('Start Rigid registration'); drawnow; end
        % Parameter scaling of the Translation and Rotation
        scale=[1 1 1   0.01 0.01 0.01];
        % Set initial rigid parameters
        par=[0 0 0 0 0 0];
    case 's',
        if(Options.Verbose), disp('Start Affine registration'); drawnow; end
        % Parameter scaling of the Translation, Rotation and Resize
        scale=[1 1 1 0.01 0.01 0.01 0.01 0.01 0.01];
        % Set initial rigid parameters
        par=[0 0 0 0 0 0  100 100 100];
    case 'a'
        if(Options.Verbose), disp('Start Affine registration'); drawnow; end
        % Parameter scaling of the Translation, Rotation, Resize and Shear
        scale=[1 1 1 0.01 0.01 0.01 0.01 0.01 0.01 0.01 0.01 0.01 0.01 0.01 0.01];
        % Set initial rigid parameters
        par=[0 0 0 0 0 0 100 100 100 0 0 0 0 0 0];
    otherwise
        warning('ICP_finite:inputs','unknown registration method');
end

% Distance error in last itteration
fval_old=inf;

% Change in distance error between two itterations
fval_perc=0;

% Array which contains the transformed points
Points_Moved=Points_Moving;

% Number of itterations
itt=0;

% Get the minimum and maximum coordinates of the static points
maxP=max(Points_Static);
minP=min(Points_Static);
Options.TolX=max(maxP-minP)/1000;

% Display information of current itteration
if(Options.Verbose)
    s=sprintf('    Itteration          Error'); disp(s);
end

% Make a uniform grid of points
% These will be used to sort the points into local groups
% to speed up the distance measurements.
spacing=size(Points_Static,1)^(1/6)*sqrt(3);
spacing_dist=max(maxP(:)-minP(:))/spacing;
xa=minP(1):spacing_dist:maxP(1);
xb=minP(2):spacing_dist:maxP(2);
xc=minP(3):spacing_dist:maxP(3);

[x,y,z]=ndgrid(xa,xb,xc);
Points_Group=[x(:) y(:) z(:)];

% Calculate the radius of a point from the uniform grid.
radius=spacing_dist*sqrt(3);

% Sort the points in to groups
Cell_Group_Static=cell(1,size(Points_Group,1));
for i=1:size(Points_Group,1)
    % Calculate distance of an uniform group point to all static points
    %distance=sum((Points_Static-repmat(Points_Group(i,:),size(Points_Static,1),1)).^2,2);
    %check=(distance<(mult*radius^2));
    check=(Points_Static(:,1)>(Points_Group(i,1)-radius))&(Points_Static(:,1)<(Points_Group(i,1)+radius))...
        &(Points_Static(:,2)>(Points_Group(i,2)-radius))&(Points_Static(:,2)<(Points_Group(i,2)+radius))...
        &(Points_Static(:,3)>(Points_Group(i,3)-radius))&(Points_Static(:,3)<(Points_Group(i,3)+radius));
    
    % Add the closest static points, if none, increase the radius of point
    % search
    mult=1;
    while(isempty(Cell_Group_Static{i}))
        Cell_Group_Static{i}=Points_Static(check,:);
        % Increase radius
        mult=mult+1.5;
        check=(Points_Static(:,1)>(Points_Group(i,1)-mult*radius))&(Points_Static(:,1)<(Points_Group(i,1)+mult*radius))...
            &(Points_Static(:,2)>(Points_Group(i,2)-mult*radius))&(Points_Static(:,2)<(Points_Group(i,2)+mult*radius))...
            &(Points_Static(:,3)>(Points_Group(i,3)-mult*radius))&(Points_Static(:,3)<(Points_Group(i,3)+mult*radius));
    end
end

% closest points for all points
Points_Match=zeros(size(Points_Moved));

while(fval_perc<(1-Options.TolP))
    itt=itt+1;
    
    % Calculate closest point for all points
    for i=1:size(Points_Moved,1)
        % Find closest group point
        Point=Points_Moved(i,:);
        dist=(Points_Group(:,1)-Point(1)).^2+(Points_Group(:,2)-Point(2)).^2+(Points_Group(:,3)-Point(3)).^2;
        [mindist,j]=min(dist);
        
        % Find closest point in group
        Points_Group_Static=Cell_Group_Static{j};
        dist=(Points_Group_Static(:,1)-Point(1)).^2+(Points_Group_Static(:,2)-Point(2)).^2+(Points_Group_Static(:,3)-Point(3)).^2;
        [mindist,j]=min(dist);
        Points_Match(i,:)=Points_Group_Static(j,:);
    end
    
    % Calculate the parameters which minimize the distance error between
    % the current closest points
    switch(Options.Optimizer)
        case 'fminlbfgs'
            % Set Registration Tollerance
            optim=struct('Display','off','TolX',Options.TolX);
            [par,fval]=fminlbfgs(@(par)affine_registration_error(par,scale,Points_Moving,Points_Match),par,optim);
        case 'fminsearch'
            % Set Registration Tollerance
            optim=struct('Display','off','TolX',Options.TolX);
            [par,fval]=fminsearch(@(par)affine_registration_error(par,scale,Points_Moving,Points_Match),par,optim);
        case 'lsqnonlin'
            % Set Registration Tollerance
            optim=optimset('Display','off','TolX',Options.TolX);
            [par,fval]=lsqnonlin(@(par)affine_registration_array(par,scale,Points_Moving,Points_Match),par,[],[],optim);
        otherwise
            disp('Unknown Optimizer.')
    end
    
    % Calculate change in error between itterations
    fval_perc=fval/fval_old;
    
    if(Options.Verbose)
        s=sprintf('     %5.0f       %13.6g ',itt,fval );
        disp(s);
    end
    
    % Store error value
    fval_old=fval;
    
    % Make the transformation matrix
    M=getransformation_matrix(par,scale);
    
    % Transform the Points
    Points_Moved=movepoints(M,Points_Moving);
end

function  [e,egrad]=affine_registration_error(par,scale,Points_Moving,Points_Static)
% Stepsize used for finite differences
delta=1e-8;

% Get current transformation matrix
M=getransformation_matrix(par,scale);

% Calculate distance error
e=calculate_distance_error(M,Points_Moving,Points_Static);

% If asked calculate finite difference error gradient
if(nargout>1)
    egrad=zeros(1,length(par));
    for i=1:length(par)
        par2=par; par2(i)=par(i)+delta;
        M=getransformation_matrix(par2,scale);
        egrad(i)=calculate_distance_error(M,Points_Moving,Points_Static)/delta;
    end
end


function [dist_total]=calculate_distance_error(M,Points_Moving,Points_Static)
% First transform the points with the transformation matrix
Points_Moved=movepoints(M,Points_Moving);
% Calculate the squared distance between the points
dist=sum((Points_Moved-Points_Static).^2,2);
% calculate the total distanse
dist_total=sum(dist);

function  [earray]=affine_registration_array(par,scale,Points_Moving,Points_Static)
% Get current transformation matrix
M=getransformation_matrix(par,scale);
% First transform the points with the transformation matrix
Points_Moved=movepoints(M,Points_Moving);
% Calculate the squared distance between the points
%earray=sum((Points_Moved-Points_Static).^2,2);
earray=(Points_Moved-Points_Static);


function Po=movepoints(M,P)
% Transform all xyz points with the transformation matrix
Po=zeros(size(P));
Po(:,1)=P(:,1)*M(1,1)+P(:,2)*M(1,2)+P(:,3)*M(1,3)+M(1,4);
Po(:,2)=P(:,1)*M(2,1)+P(:,2)*M(2,2)+P(:,3)*M(2,3)+M(2,4);
Po(:,3)=P(:,1)*M(3,1)+P(:,2)*M(3,2)+P(:,3)*M(3,3)+M(3,4);


function M=getransformation_matrix(par,scale)
% This function will transform the parameter vector in to a
% a transformation matrix

% Scale the input parameters
par=par.*scale;
switch(length(par))
    case 6  % Translation and Rotation
        M=make_transformation_matrix(par(1:3),par(4:6));
    case 9  % Translation, Rotation and Resize
        M=make_transformation_matrix(par(1:3),par(4:6),par(7:9));
    case 15 % Translation, Rotation, Resize and Shear
        M=make_transformation_matrix(par(1:3),par(4:6),par(7:9),par(10:15));
end


function M=make_transformation_matrix(t,r,s,h)
% This function make_transformation_matrix.m creates an affine
% 2D or 3D transformation matrix from translation, rotation, resize and shear parameters
%
% M=make_transformation_matrix.m(t,r,s,h)
%
% inputs (3D),
%   t: vector [translateX translateY translateZ]
%   r: vector [rotateX rotateY rotateZ]
%   s: vector [resizeX resizeY resizeZ]
%   h: vector [ShearXY, ShearXZ, ShearYX, ShearYZ, ShearZX, ShearZY]
%
% outputs,
%   M: 3D affine transformation matrix
%
% examples,
%   % 3D
%   M=make_transformation_matrix([0.5 0 0],[1 1 1.2],[0 0 0])
%
% Function is written by D.Kroon University of Twente (October 2008)

% Process inputs
if(~exist('r','var')||isempty(r)), r=[0 0 0]; end
if(~exist('s','var')||isempty(s)), s=[1 1 1]; end
if(~exist('h','var')||isempty(h)), h=[0 0 0 0 0 0]; end

% Calculate affine transformation matrix
if(length(t)==2)
    % Make the transformation matrix
    M=mat_tra_2d(t)*mat_siz_2d(s)*mat_rot_2d(r)*mat_shear_2d(h);
else
    % Make the transformation matrix
    M=mat_tra_3d(t)*mat_siz_3d(s)*mat_rot_3d(r)*mat_shear_3d(h);
end

function M=mat_rot_3d(r)
r=r*(pi/180);
Rx=[1 0 0 0;
    0 cos(r(1)) -sin(r(1)) 0;
    0 sin(r(1)) cos(r(1)) 0;
    0 0 0 1];

Ry=[cos(r(2)) 0 sin(r(2)) 0;
    0 1 0 0;
    -sin(r(2)) 0 cos(r(2)) 0;
    0 0 0 1];

Rz=[cos(r(3)) -sin(r(3)) 0 0;
    sin(r(3)) cos(r(3)) 0 0;
    0 0 1 0;
    0 0 0 1];
M=Rx*Ry*Rz;

function M=mat_siz_3d(s)
M=[s(1) 0    0    0;
    0    s(2) 0    0;
    0    0    s(3) 0;
    0    0    0    1];

function M=mat_shear_3d(h)
M=[1    h(1) h(2) 0;
    h(3) 1    h(4) 0;
    h(5) h(6) 1    0;
    0 0 0 1];

function M=mat_tra_3d(t)
M=[1 0 0 t(1);
    0 1 0 t(2);
    0 0 1 t(3);
    0 0 0 1];



