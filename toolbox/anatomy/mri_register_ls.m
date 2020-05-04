function Transf = mri_register_ls(sMri)
% MRI_REGISTER_LS:  Register one MRI volume on a template, using SPM's least square algorithm.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2015

% =========================================================================
% spm_normalise
% =========================================================================
% Spatial (stereotactic) normalization
%__________________________________________________________________________
%
% References:
% K.J. Friston, J. Ashburner, C.D. Frith, J.-B. Poline, J.D. Heather,
% and R.S.J. Frackowiak
% Spatial Registration and Normalization of Images.
% Human Brain Mapping 2:165-189, 1995.
% 
% J. Ashburner, P. Neelin, D.L. Collins, A.C. Evans and K.J. Friston
% Incorporating Prior Knowledge into Image Registration.
% NeuroImage 6:344-352, 1997.
%
% J. Ashburner and K.J. Friston
% Nonlinear spatial normalization using basis functions.
% Human Brain Mapping, 7(4):254-266, 1999.
%__________________________________________________________________________
% Copyright (C) 2002-2013 Wellcome Trust Centre for Neuroimaging

% Load the two volumes
VG = spm_vol('C:\Work\Dev\Divers\spm12\canonical\avg152T1.nii');
VF = spm_vol('C:\Work\RawData\Test\SPM_norm\FT_T1.nii');

% Read volume
DF = spm_data_read(VF);
DG = spm_data_read(VG);

% Reset volume origin to the middle of the volume
mriTransf = eye(4);
mriTransf(1:3,1:3) = diag(sMri.Voxsize);
mriTransf(1:3,4) = - ceil(size(sMri.Cube(:,:,:,1)) / 2);

VF.mat = mriTransf;

flags.smosrc = 0;
flags.smoref = 8;
flags.regtype = 'mni';
flags.weight = '';
flags.cutoff = 25;
flags.nits = 0;
flags.graphics = 1;
flags.reg = 1;

% Compute global mean F 
iD = isfinite(DF);
S   = mean(DF(iD)) / 8;
GXF = mean(DF(iD & (DF > S)));
% Compute global mean G
iD = isfinite(DG);
S   = mean(DG(iD)) / 8;
GXG = mean(DG(iD & (DG > S)));

% Rescale images so that globals are better conditioned
VF1 = VF;
VF1.pinfo(1:2,:) = VF.pinfo(1:2,:) / GXF;
VG1 = bst_spm_smoothto8bit(VG, flags.smoref);
VG1.pinfo(1:2,:) = VG1.pinfo(1:2,:) / GXG;


% Affine Normalisation
%--------------------------------------------------------------------------
fprintf('SPM> Coarse Affine Registration..\n');
aflags = struct('sep',     max(flags.smoref, flags.smosrc), ...
                'regtype', flags.regtype, ...
                'WG',      [], ...
                'WF',      [], ...
                'globnorm',0);
aflags.sep = max(aflags.sep, max(sqrt(sum(VG(1).mat(1:3,1:3).^2))));
aflags.sep = max(aflags.sep, max(sqrt(sum(VF(1).mat(1:3,1:3).^2))));

M = eye(4);
[M,scal]  = spm_affreg(VG1, VF1, aflags, M);

fprintf('Fine Affine Registration..\n');
aflags.WG  = [];
aflags.WF  = [];
aflags.sep = aflags.sep/2;
[M,scal]   = spm_affreg(VG1, VF1, aflags, M,scal);

% Final transformation
Transf = M * mriTransf;


end



%% =================================================================================
%  ====== SPM FUNCTIONS ============================================================
%  =================================================================================

%% =========================================================================
%  bst_spm_smoothto8bit
%  =========================================================================
% 3 dimensional convolution of an image to 8bit data in memory
% FORMAT VO = smoothto8bit(V,fwhm)
% V     - mapped image to be smoothed
% fwhm  - FWHM of Guassian filter width in mm
% VO    - smoothed volume in a form that can be used by the
%         spm_*_vol.mex* functions.
%_______________________________________________________________________
function VO = bst_spm_smoothto8bit(V,fwhm)
    vx   = sqrt(sum(V.mat(1:3,1:3).^2));
    s    = (fwhm./vx./sqrt(8*log(2)) + eps).^2;
    r    = cell(1,3);
    for i=1:3,
        r{i}.s = ceil(3.5*sqrt(s(i)));
        x      = -r{i}.s:r{i}.s;
        r{i}.k = exp(-0.5 * (x.*x)/s(i))/sqrt(2*pi*s(i));
        r{i}.k = r{i}.k/sum(r{i}.k);
    end

    buff = zeros([V.dim(1:2) r{3}.s*2+1]);

    VO        = V;
    VO.dt     = [spm_type('uint8') spm_platform('bigend')];
    V0.dat    = uint8(0);
    V0.dat(VO.dim(1:3)) = uint8(0);
    VO.pinfo  = [];

    for i=1:V.dim(3)+r{3}.s,
        if i<=V.dim(3),
            img      = spm_slice_vol(V,spm_matrix([0 0 i]),V.dim(1:2),0);
            msk      = find(~isfinite(img));
            img(msk) = 0;
            buff(:,:,rem(i-1,r{3}.s*2+1)+1) = ...
                conv2(conv2(img,r{1}.k,'same'),r{2}.k','same');
        else
            buff(:,:,rem(i-1,r{3}.s*2+1)+1) = 0;
        end

        if i>r{3}.s,
            kern    = zeros(size(r{3}.k'));
            kern(rem((i:(i+r{3}.s*2))',r{3}.s*2+1)+1) = r{3}.k';
            img     = reshape(buff,[prod(V.dim(1:2)) r{3}.s*2+1])*kern;
            img     = reshape(img,V.dim(1:2));
            ii      = i-r{3}.s;
            mx      = max(img(:));
            mn      = min(img(:));
            if mx==mn, mx=mn+eps; end
            VO.pinfo(1:2,ii) = [(mx-mn)/255 mn]';
            VO.dat(:,:,ii)   = uint8(round((img-mn)*(255/(mx-mn))));
        end
    end
end


%% =========================================================================
%  bst_spm_affreg
%  =========================================================================
% Affine registration using least squares.
% FORMAT [M,scal] = bst_spm_affreg(VG,VF,flags,M0,scal0)
%
% VG        - Vector of template volumes.
% VF        - Source volume.
% flags     - a structure containing various options.  The fields are:
%             WG       - Weighting volume for template image(s).
%             WF       - Weighting volume for source image
%                        Default to [].
%             sep      - Approximate spacing between sampled points (mm).
%                        Defaults to 5.
%             regtype  - regularisation type.  Options are:
%                        'none'  - no regularisation
%                        'rigid' - almost rigid body
%                        'subj'  - inter-subject registration (default).
%                        'mni'   - registration to ICBM templates
%             globnorm - Global normalisation flag (1)
% M0        - (optional) starting estimate. Defaults to eye(4).
% scal0     - (optional) starting estimate.
%
% M         - affine transform, such that voxels in VF map to those in
%             VG by   VG.mat\M*VF.mat
% scal      - scaling factors for VG
%
% When only one template is used, then the cost function is approximately
% symmetric, although a linear combination of templates can be used.
% Regularisation is based on assuming a multi-normal distribution for the
% elements of the Henckey Tensor. See:
% "Non-linear Elastic Deformations". R. W. Ogden (Dover), 1984.
% Weighting for the regularisation is determined approximately according
% to:
% "Incorporating Prior Knowledge into Image Registration"
% J. Ashburner, P. Neelin, D. L. Collins, A. C. Evans & K. J. Friston.
% NeuroImage 6:344-352 (1997).
%
%_______________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging
% John Ashburner
function [M,scal] = bst_spm_affreg(VG,VF,flags,M,scal)
    if nargin<5, scal = ones(length(VG),1); end;
    if nargin<4, M    = eye(4);             end;

    def_flags = struct('sep',5, 'regtype','subj','WG',[],'WF',[],'globnorm',1,'debug',0);
    if nargin < 3 || ~isstruct(flags),
        flags = def_flags;
    else
        fnms = fieldnames(def_flags);
        for i=1:length(fnms),
            if ~isfield(flags,fnms{i}),
                flags.(fnms{i}) = def_flags.(fnms{i});
            end;
        end;
    end;

    % Check to ensure inputs are valid...
    % ---------------------------------------------------------------
    if length(VF)>1, error('Can not use more than one source image'); end;
    if ~isempty(flags.WF),
        if length(flags.WF)>1,
            error('Can only use one source weighting image');
        end;
        if any(any((VF.mat-flags.WF.mat).^2>1e-8)),
            error('Source and its weighting image must have same orientation');
        end;
        if any(any(VF.dim(1:3)-flags.WF.dim(1:3))),
            error('Source and its weighting image must have same dimensions');
        end;
    end;
    if ~isempty(flags.WG),
        if length(flags.WG)>1,
            error('Can only use one template weighting image');
        end;
        tmp = reshape(cat(3,VG(:).mat,flags.WG.mat),16,length(VG)+length(flags.WG));
    else
        tmp = reshape(cat(3,VG(:).mat),16,length(VG));
    end;
    if any(any(diff(tmp,1,2).^2>1e-8)),
        error('Reference images must all have the same orientation');
    end;
    if ~isempty(flags.WG),
        tmp = cat(1,VG(:).dim,flags.WG.dim);
    else
        tmp = cat(1,VG(:).dim);
    end;
    if any(any(diff(tmp(:,1:3),1,1))),
        error('Reference images must all have the same dimensions');
    end;
    % ---------------------------------------------------------------

    % Generate points to sample from, adding some jitter in order to
    % make the cost function smoother.
    % ---------------------------------------------------------------
    if exist('rng', 'file')
        rng('default');
    else
        rand('state',1);
    end
    dg   = VG(1).dim(1:3);
    df   = VF(1).dim(1:3);

    if length(VG)==1,
        skip = sqrt(sum(VG(1).mat(1:3,1:3).^2)).^(-1)*flags.sep;
        [x1,x2,x3]=ndgrid(1:skip(1):dg(1)-.5, 1:skip(2):dg(2)-.5, 1:skip(3):dg(3)-.5);
        x1   = x1 + rand(size(x1))*0.5; x1 = x1(:);
        x2   = x2 + rand(size(x2))*0.5; x2 = x2(:);
        x3   = x3 + rand(size(x3))*0.5; x3 = x3(:);
    end;

    skip = sqrt(sum(VF(1).mat(1:3,1:3).^2)).^(-1)*flags.sep;
    [y1,y2,y3]=ndgrid(1:skip(1):df(1)-.5, 1:skip(2):df(2)-.5, 1:skip(3):df(3)-.5);
    y1   = y1 + rand(size(y1))*0.5; y1 = y1(:);
    y2   = y2 + rand(size(y2))*0.5; y2 = y2(:);
    y3   = y3 + rand(size(y3))*0.5; y3 = y3(:);
    % ---------------------------------------------------------------

    if flags.globnorm,
        % Scale all images approximately equally
        % ---------------------------------------------------------------
        for i=1:length(VG),
            VG(i).pinfo(1:2,:) = VG(i).pinfo(1:2,:)/spm_global(VG(i));
        end;
        VF(1).pinfo(1:2,:) = VF(1).pinfo(1:2,:)/spm_global(VF(1));
    end;
    % ---------------------------------------------------------------

    if length(VG)==1,
        [G,dG1,dG2,dG3]  = spm_sample_vol(VG(1),x1,x2,x3,1);
        if ~isempty(flags.WG),
            WG = abs(spm_sample_vol(flags.WG,x1,x2,x3,1))+eps;
            WG(~isfinite(WG)) = 1;
        end;
    end;

    [F,dF1,dF2,dF3]  = spm_sample_vol(VF(1),y1,y2,y3,1);
    if ~isempty(flags.WF),
        WF = abs(spm_sample_vol(flags.WF,y1,y2,y3,1))+eps;
        WF(~isfinite(WF)) = 1;
    end;
    % ---------------------------------------------------------------
    n_main_its = 0;
    ss         = Inf;
    W          = [Inf Inf Inf];
    est_smo    = 1;
    % ---------------------------------------------------------------

    for iter=1:256,
        pss   = ss;
        p0    = [0 0 0  0 0 0  1 1 1  0 0 0];

        % Initialise the cost function and its 1st and second derivatives
        % ---------------------------------------------------------------
        n     = 0;
        ss    = 0;
        Beta  = zeros(12+length(VG),1);
        Alpha = zeros(12+length(VG));

        if length(VG)==1,
            % Make the cost function symmetric
            % ---------------------------------------------------------------

            % Build a matrix to rotate the derivatives by, converting from
            % derivatives w.r.t. changes in the overall affine transformation
            % matrix, to derivatives w.r.t. the parameters p.
            % ---------------------------------------------------------------
            dt  = 0.0001;
            R   = eye(13);
            MM0 = inv(VG.mat)*inv(spm_matrix(p0))*VG.mat;
            for i1=1:12,
                p1          = p0;
                p1(i1)      = p1(i1)+dt;
                MM1         = (inv(VG.mat)*inv(spm_matrix(p1))*(VG.mat));
                R(1:12,i1)  = reshape((MM1(1:3,:)-MM0(1:3,:))/dt,12,1);
            end;
            % ---------------------------------------------------------------
            [t1,t2,t3] = coords((M*VF(1).mat)\VG(1).mat,x1,x2,x3);
            msk        = find((t1>=1 & t1<=df(1) & t2>=1 & t2<=df(2) & t3>=1 & t3<=df(3)));
            if (length(msk) < 32)
                error('Insufficient image overlap.');
            end
            t1         = t1(msk);
            t2         = t2(msk);
            t3         = t3(msk);
            t          = spm_sample_vol(VF(1), t1,t2,t3,1);

            % Get weights
            % ---------------------------------------------------------------
            if ~isempty(flags.WF) || ~isempty(flags.WG),
                if isempty(flags.WF),
                    wt = WG(msk);
                else
                    wt = spm_sample_vol(flags.WF(1), t1,t2,t3,1)+eps;
                    wt(~isfinite(wt)) = 1;
                    if ~isempty(flags.WG), wt = 1./(1./wt + 1./WG(msk)); end;
                end;
                wt = sparse(1:length(wt),1:length(wt),wt);
            else
                % wt = speye(length(msk));
                wt = [];
            end;
            % ---------------------------------------------------------------
            clear t1 t2 t3

            % Update the cost function and its 1st and second derivatives.
            % ---------------------------------------------------------------
            [AA,Ab,ss1,n1] = costfun(x1,x2,x3,dG1,dG2,dG3,msk,scal^(-2)*t,G(msk)-(1/scal)*t,wt);
            Alpha = Alpha + R'*AA*R;
            Beta  = Beta  + R'*Ab;
            ss    = ss    + ss1;
            n     = n     + n1;
            % t     = G(msk) - (1/scal)*t;
        end;

        if 1,
            % Build a matrix to rotate the derivatives by, converting from
            % derivatives w.r.t. changes in the overall affine transformation
            % matrix, to derivatives w.r.t. the parameters p.
            % ---------------------------------------------------------------
            dt = 0.0001;
            R  = eye(12+length(VG));
            MM0 = inv(M*VF.mat)*spm_matrix(p0)*M*VF.mat;
            for i1=1:12,
                p1          = p0;
                p1(i1)      = p1(i1)+dt;
                MM1         = (inv(M*VF.mat)*spm_matrix(p1)*M*VF.mat);
                R(1:12,i1)  = reshape((MM1(1:3,:)-MM0(1:3,:))/dt,12,1);
            end;
            % ---------------------------------------------------------------
            [t1,t2,t3] = coords(VG(1).mat\M*VF(1).mat,y1,y2,y3);
            msk        = find((t1>=1 & t1<=dg(1) & t2>=1 & t2<=dg(2) & t3>=1 & t3<=dg(3)));
            if (length(msk) < 32)
                error('Insufficient image overlap.')
            end

            t1 = t1(msk);
            t2 = t2(msk);
            t3 = t3(msk);
            t  = zeros(length(t1),length(VG));

            % Get weights
            % ---------------------------------------------------------------
            if ~isempty(flags.WF) || ~isempty(flags.WG),
                if isempty(flags.WG),
                    wt = WF(msk);
                else
                    wt = spm_sample_vol(flags.WG(1), t1,t2,t3,1)+eps;
                    wt(~isfinite(wt)) = 1;
                    if ~isempty(flags.WF), wt = 1./(1./wt + 1./WF(msk)); end;
                end;
                wt = sparse(1:length(wt),1:length(wt),wt);
            else
                wt = speye(length(msk));
            end;
            % ---------------------------------------------------------------

            if est_smo,
                % Compute derivatives of residuals in the space of F
                % ---------------------------------------------------------------
                [ds1,ds2,ds3] = transform_derivs(VG(1).mat\M*VF(1).mat,dF1(msk),dF2(msk),dF3(msk));
                for i = 1:length(VG)
                    [t(:,i),dt1,dt2,dt3] = spm_sample_vol(VG(i), t1,t2,t3,1);
                    ds1   = ds1 - dt1*scal(i); clear dt1
                    ds2   = ds2 - dt2*scal(i); clear dt2
                    ds3   = ds3 - dt3*scal(i); clear dt3
                end
                dss   = [ds1'*wt*ds1 ds2'*wt*ds2 ds3'*wt*ds3];
                clear ds1 ds2 ds3
            else
                for i=1:length(VG)
                    t(:,i)= spm_sample_vol(VG(i), t1,t2,t3,1);
                end
            end;

            clear t1 t2 t3

            % Update the cost function and its 1st and second derivatives.
            % ---------------------------------------------------------------
            [AA,Ab,ss2,n2] = costfun(y1,y2,y3,dF1,dF2,dF3,msk,-t,F(msk)-t*scal,wt);
            Alpha = Alpha  + R'*AA*R;
            Beta  = Beta   + R'*Ab;
            ss    = ss     + ss2;
            n     = n      + n2;
        end;

        if est_smo,
            % Compute a smoothness correction from the residuals and their
            % derivatives.  This is analagous to the one used in:
            %   "Analysis of fMRI Time Series Revisited"
            %   Friston KJ, Holmes AP, Poline JB, Grasby PJ, Williams SCR,
            %   Frackowiak RSJ, Turner R.  Neuroimage 2:45-53 (1995).
            % ---------------------------------------------------------------
            vx     = sqrt(sum(VG(1).mat(1:3,1:3).^2));
            pW     = W;
            W      = (2*dss/ss2).^(-.5).*vx;
            W      = min(pW,W);
            if (length(VG) == 1)
                dens=2; 
            else
                dens=1; 
            end
            smo = prod(min(dens*flags.sep/sqrt(2*pi)./W,[1 1 1]));
            est_smo=0;
            n_main_its = n_main_its + 1;
        end;

        % Update the parameter estimates
        % ---------------------------------------------------------------
        nu      = n*smo;
        sig2    = ss/nu;
        [d1,d2] = reg(M,12+length(VG),flags.regtype);

        soln    = (Alpha/sig2+d2)\(Beta/sig2-d1);
        scal    = scal - soln(13:end);
        M       = spm_matrix(p0 + soln(1:12)')*M;

        % If cost function stops decreasing, then re-estimate smoothness
        % and try again.  Repeat a few times.
        % ---------------------------------------------------------------
        ss = ss/n;
        if iter>1, spm_plot_convergence('Set',ss); end;
        if (pss-ss)/pss < 1e-6,
            est_smo = 1;
        end;
        if n_main_its>3, break; end;

    end;
end


%% =========================================================================
%  transform_derivs
%  =========================================================================
% Given the derivatives of a scalar function, return those of the
% affine transformed function
function [X1,Y1,Z1] = transform_derivs(Mat,X,Y,Z)
    t1 = Mat(1:3,1:3);
    t2 = eye(3);
    if sum((t1(:)-t2(:)).^2) < 1e-12,
            X1 = X;Y1 = Y; Z1 = Z;
    else
            X1    = Mat(1,1)*X + Mat(1,2)*Y + Mat(1,3)*Z;
            Y1    = Mat(2,1)*X + Mat(2,2)*Y + Mat(2,3)*Z;
            Z1    = Mat(3,1)*X + Mat(3,2)*Y + Mat(3,3)*Z;
    end;
end



%% =========================================================================
%  reg
%  =========================================================================
% Analytically compute the first and second derivatives of a penalty function w.r.t. changes in parameters.
function [d1,d2] = reg(M,n,typ)
    if nargin<3, typ = 'subj'; end;
    if nargin<2, n   = 13;     end;

    [mu,isig] = spm_affine_priors(typ);
    ds  = 0.000001;
    d1  = zeros(n,1);
    d2  = zeros(n);
    p0  = [0 0 0  0 0 0  1 1 1  0 0 0];
    h0  = penalty(p0,M,mu,isig);
    for i=7:12, % derivatives are zero w.r.t. rotations and translations
        p1    = p0;
        p1(i) = p1(i)+ds;
        h1    = penalty(p1,M,mu,isig);
        d1(i) = (h1-h0)/ds; % First derivative
        for j=7:12,
            p2    = p0;
            p2(j) = p2(j)+ds;
            h2    = penalty(p2,M,mu,isig);
            p3    = p1;
            p3(j) = p3(j)+ds;
            h3    = penalty(p3,M,mu,isig);
            d2(i,j) = ((h3-h2)/ds-(h1-h0)/ds)/ds; % Second derivative
        end;
    end;
end


%% =========================================================================
%  penalty
%  =========================================================================
% Return a penalty based on the elements of an affine transformation, which is given by:
%   spm_matrix(p)*M
% The penalty is based on the 6 unique elements of the Hencky tensor
% elements being multinormally distributed.
function h = penalty(p,M,mu,isig)
    % Unique elements of symmetric 3x3 matrix.
    els = [1 2 3 5 6 9];

    T = spm_matrix(p)*M;
    T = T(1:3,1:3);
    T = 0.5*logm(T'*T);
    T = T(els)' - mu;
    h = T'*isig*T;
end



%% =========================================================================
%  coords
%  =========================================================================
function [y1,y2,y3]=coords(M,x1,x2,x3)
    y1 = M(1,1)*x1 + M(1,2)*x2 + M(1,3)*x3 + M(1,4);
    y2 = M(2,1)*x1 + M(2,2)*x2 + M(2,3)*x3 + M(2,4);
    y3 = M(3,1)*x1 + M(3,2)*x2 + M(3,3)*x3 + M(3,4);
end


%% =========================================================================
%  make_A
%  =========================================================================
% Generate part of a design matrix using the chain rule...
% df/dm = df/dy * dy/dm
% where
%   df/dm is the rate of change of intensity w.r.t. affine parameters
%   df/dy is the gradient of the image f
%   dy/dm crange of position w.r.t. change of parameters
function A = make_A(x1,x2,x3,dG1,dG2,dG3,t)
    A  = [x1.*dG1 x1.*dG2 x1.*dG3 ...
          x2.*dG1 x2.*dG2 x2.*dG3 ...
          x3.*dG1 x3.*dG2 x3.*dG3 ...
              dG1     dG2     dG3    t];
end


%% =========================================================================
%  costfun
%  =========================================================================
function [AA,Ab,ss,n] = costfun(x1,x2,x3,dG1,dG2,dG3,msk,lastcols,b,wt)
    chunk = 10240;
    lm    = length(msk);
    AA    = zeros(12+size(lastcols,2));
    Ab    = zeros(12+size(lastcols,2),1);
    ss    = 0;
    n     = 0;

    for i=1:ceil(lm/chunk),
        ind  = (((i-1)*chunk+1):min(i*chunk,lm))';
        msk1 = msk(ind);
        A1   = make_A(x1(msk1),x2(msk1),x3(msk1),dG1(msk1),dG2(msk1),dG3(msk1),lastcols(ind,:));
        b1   = b(ind);
        if ~isempty(wt),
            wt1   = wt(ind,ind);
            AA    = AA  + A1'*wt1*A1;
            Ab    = Ab  + (b1'*wt1*A1)';
            ss    = ss  + b1'*wt1*b1;
            n     = n   + trace(wt1);
        else
            AA    = AA  + A1'*A1;
            Ab    = Ab  + (b1'*A1)';
            ss    = ss  + b1'*b1;
            n     = n   + length(msk1);
        end;
    end;
end




