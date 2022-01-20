function Transf = mri_normalize_maff(sMri, TpmFile)
% MRI_NORMALIZE_MAFF: Linear normalization to the MNI ICBM152 space 
% using SPM's mutual information algorithm (affine 4x4 transformation)
%
% The MNI152 space depends on the TPM.nii file given in input:
%    - Default in SPM12    : MNI152NLin6Sym template
%    - Default in Lead-DBS : MNI152NLin2009b template

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: John Ashburner, 2008-2014
%          Francois Tadel, 2015-2020  (Brainstorm wrapper)

% Loading the tissue probability map
bst_progress('text', 'Loading tissue probability map...');
tpm = bst_spm_load_priors8(TpmFile);

% Reset volume origin to the middle of the volume
mriTransf = eye(4);
mriTransf(1:3,1:3) = diag(sMri.Voxsize);
mriTransf(1:3,4) = - ceil(size(sMri.Cube(:,:,:,1)) / 2);
% Registration
samp = 3;
bst_progress('text', 'SPM registration (maff): First pass...');
Affine = bst_spm_maff8(sMri, mriTransf, samp, 16, tpm, []);      % Closer to rigid
bst_progress('text', 'SPM registration (maff): Second pass...');
Affine = bst_spm_maff8(sMri, mriTransf, samp, 0,  tpm, Affine);
% Final transformation
Transf = Affine * mriTransf;

end



%% =================================================================================
%  ====== SPM FUNCTIONS ============================================================
%  =================================================================================

%% ==========================================================================
%  spm_load_priors8
%  ==========================================================================
% Copyright (C) 2008-2014 Wellcome Trust Centre for Neuroimaging
% John Ashburner
function tpm = bst_spm_load_priors8(TpmFile)
    % Read template volume
    sMri = in_mri_nii(TpmFile, 1, 0, 0);
    sMri.Cube = double(sMri.Cube);
    % If first dimension is flipped: flip it back
    if (sMri.Header.nifti.vox2ras(1,1) < 1)
        sMri.Cube = bst_flip(sMri.Cube, 1);
        sMri.Header.nifti.vox2ras(1,:) = -sMri.Header.nifti.vox2ras(1,:);
    end
    % Constrain volume to be in the range [0,1]
    sMri.Cube = max(min(sMri.Cube, 1), 0);
    % Get reference change for this subject
    tpm.M = sMri.Header.nifti.vox2ras;
    tpm.M(1:3,4) = tpm.M(1:3,4) - sum(tpm.M(1:3,1:3),2);
    % Copy volume
    Nv = size(sMri.Cube,4);
    tpm.dat = cell(Nv,1);
    for iv = 1:(Nv)
        tpm.dat{iv} = sMri.Cube(:,:,:,iv);
    end
    % Options
    tiny = 1e-4;
    deg = 1;
    tpm.bg1 = zeros(Nv,1);
    for iv = 1:Nv
        tpm.bg1(iv) = mean(mean(tpm.dat{iv}(:,:,1)));
        tpm.bg2(iv) = mean(mean(tpm.dat{iv}(:,:,end)));
        tpm.dat{iv} = spm_bsplinc(log(tpm.dat{iv}+tiny),[deg deg deg  0 0 0]);
    end
    tpm.tiny = tiny;
    tpm.deg  = deg+1;
end


%% ===== SPM_MAFF8 =====
% Affine registration to MNI space using mutual information
% sMri    - Brainstorm MRI structure
% samp    - distance between sample points (mm).  Small values are better, but things run more slowly.
% fwhm    - smoothness estimate for computing a fudge factor.  Estimate is a full width at half maximum of a Gaussian (in mm). 
% tpm     - data structure encoding a tissue probability map
% M       - starting estimates for the affine transform (or [] to use default values).
% regtype - 'mni'     - registration of European brains with MNI space
%__________________________________________________________________________
% Copyright (C) 2008-2014 Wellcome Trust Centre for Neuroimaging
% John Ashburner
function Affine = bst_spm_maff8(sMri, MG,samp,fwhm,tpm,Affine)

    % ===== LOADBUF =====
    mriSize = size(sMri.Cube);
    sk      = max([1 1 1],round(samp*[1 1 1]./sMri.Voxsize));
    [x1,x2] = ndgrid(1:sk(1):mriSize(1), 1:sk(2):mriSize(2));
    x3      = 1:sk(3):mriSize(3);

    % Fudge Factor: to (approximately) account for non-independence of voxels
    s    = (fwhm+mean(sMri.Voxsize)) / sqrt(8*log(2));           % Standard deviation
    ff   = prod(4*pi*(s./sMri.Voxsize./sk).^2 + 1)^(1/2);

    % Load the image
    g = double(sMri.Cube(1:3:end, 1:3:end, 1:3:end, 1));  % Use first volume only
    d = size(g);

    mn = min(g(:));
    mx = max(g(:));
    sf = [mn 1;mx 1]\[1;4000];
    h  = zeros(4000,1);
    for  i= 1:d(3)
        p = g(:,:,i);
        p = p(isfinite(p) & (p~=0));
        p = round(p*sf(1)+sf(2));
        h = h + accumarray(p(:),1,[4000,1]);
    end;
    h  = cumsum(h)/sum(h);
    mn = (find(h>(0.0005),1)-sf(2))/sf(1);
    mx = (find(h>(0.9995),1)-sf(2))/sf(1);
    sf = [mn 1;mx 1]\[0;255];

    scrand = 1;
    if exist('rng', 'file')
        rng('default');
    else
        rand('seed',1);
    end

    cl = cell(1,d(3));
    M = struct('nm',cl,'msk',cl,'g',cl);
    for i = 1:d(3)
        gz         = g(:,:,i);
        M(i).msk = isfinite(gz) & gz~=0;
        M(i).nm  = sum(M(i).msk(:));
        if scrand
            gz = gz + rand(size(gz))*scrand-scrand/2; 
        end
        gz      = gz(M(i).msk)*sf(1)+sf(2);
        M(i).g  = uint8(max(min(round(gz),255),0));
    end;

    
    % ===== AFFREG =====
    [mu,isig] = bst_spm_affine_priors();
    mu        = [zeros(6,1) ; mu];
    Alpha0    = [eye(6,6)*0.00001 zeros(6,6) ; zeros(6,6) isig]*ff;

    if ~isempty(Affine),
        sol  = M2P(Affine);
    else
        sol  = mu;
    end

    sol1 = sol;
    ll   = -Inf;
    
    % === spm_smoothkern ===
    fwhm_krn = 4;
    x = (-256:256)';
    % Variance from FWHM
    s = (fwhm_krn/sqrt(8*log(2)))^2+eps;
    % Gaussian convolved with 0th degree B-spline
    w1  = 1/sqrt(2*s);
    krn = 0.5*(erf(w1*(x+0.5))-erf(w1*(x-0.5)));
    krn(krn<0) = 0;
    % ======================

    stepsize = 1;
    h1 = ones(256,numel(tpm.dat));
    for iter=1:200
        penalty = 0.5 * (sol1-mu)' * Alpha0 * (sol1-mu);
        T   = tpm.M \ P2M(sol1) * MG;
        R   = derivs(tpm.M,sol1,MG);
        y1a = T(1,1)*x1 + T(1,2)*x2 + T(1,4);
        y2a = T(2,1)*x1 + T(2,2)*x2 + T(2,4);
        y3a = T(3,1)*x1 + T(3,2)*x2 + T(3,4);

        for i=1:length(x3)
            if ~M(i).nm
                continue; 
            end
            y1    = y1a(M(i).msk) + T(1,3)*x3(i);
            y2    = y2a(M(i).msk) + T(2,3)*x3(i);
            y3    = y3a(M(i).msk) + T(3,3)*x3(i);

            msk   = y3>=1;
            y1    = y1(msk);
            y2    = y2(msk);
            y3    = y3(msk);
            b     = bst_spm_sample_priors8(tpm,y1,y2,y3);                        %%%%%%%%%%%%%%%%%% SLOW
            M(i).b    = b;
            M(i).msk1 = msk;
            M(i).nm1  = sum(M(i).msk1);
        end

        ll0 = 0;
        for subit=1:60
            h0  = zeros(256,numel(tpm.dat))+eps;
            ll1 = ll0;
            ll0 = 0;
            for i=1:length(x3)
                if ~M(i).nm || ~M(i).nm1
                    continue; 
                end
                gm    = double(M(i).g(M(i).msk1))+1;
                q     = zeros(numel(gm),size(h0,2));
                for k = 1:size(h0,2),
                    q(:,k) = h1(gm(:),k).*M(i).b{k};                            %%%%%%%%%%%%%%%%%% SLOW
                end
                sq = sum(q,2) + eps;
                if ~rem(subit,4)
                    ll0 = ll0 + sum(log(sq));
                end
                for k = 1:size(h0,2)
                    h0(:,k) = h0(:,k) + accumarray(gm,q(:,k)./sq,[256 1]);      %%%%%%%%%%%%%%%%%% SLOW
                end
            end
            if (~rem(subit,4) && (ll0-ll1)/sum(h0(:)) < 1e-5)
                break; 
            end
            h1  = conv2((h0+eps)/sum(h0(:)),krn,'same');

            h1  = h1./(sum(h1,2)*sum(h1,1));
        end
        for i=1:length(x3)
            M(i).b    = [];
            M(i).msk1 = [];
        end

        ssh   = sum(h0(:));
        ll1   = (sum(sum(h0.*log(h1))) - penalty)/ssh/log(2);
        disp(sprintf('SPM> Iteration #%d: Log-likelihood %f', iter, ll1));

        if (abs(ll1-ll) < 1e-5)
            break; 
        end
        if (ll1<ll)
            stepsize = stepsize*0.5;
            h1       = oh1;
            R        = derivs(tpm.M,sol,MG);
            if (stepsize < 0.5^8)
                break; 
            end
        else
            stepsize = min(stepsize*1.1,1);
            oh1      = h1;
            ll       = ll1;
            sol      = sol1;
        end
        Alpha = zeros(12);
        Beta  = zeros(12,1);
        for i=1:length(x3)
            if ~M(i).nm
                continue; 
            end
            gi    = double(M(i).g)+1;
            y1    = y1a(M(i).msk) + T(1,3)*x3(i);
            y2    = y2a(M(i).msk) + T(2,3)*x3(i);
            y3    = y3a(M(i).msk) + T(3,3)*x3(i);

            msk   = y3>=1;
            y1    = y1(msk);
            y2    = y2(msk);
            y3    = y3(msk);
            gi    = gi(msk);

            nz    = size(y1,1);
            if nz
                mi    = zeros(nz,1) + eps;
                dmi1  = zeros(nz,1);
                dmi2  = zeros(nz,1);
                dmi3  = zeros(nz,1);
                [b, db1, db2, db3] = bst_spm_sample_priors8(tpm,y1,y2,y3);            %%%%%%%%%%%%%%%%%% SLOW

                for k=1:size(h0,2)
                    tmp  = h1(gi,k);
                    mi   = mi   + tmp.*b{k};
                    dmi1 = dmi1 + tmp.*db1{k};
                    dmi2 = dmi2 + tmp.*db2{k};
                    dmi3 = dmi3 + tmp.*db3{k};
                end
                dmi1 = dmi1./mi;
                dmi2 = dmi2./mi;
                dmi3 = dmi3./mi;
                x1m  = x1(M(i).msk); x1m = x1m(msk);
                x2m  = x2(M(i).msk); x2m = x2m(msk);
                x3m  = x3(i);
                A = [dmi1.*x1m dmi2.*x1m dmi3.*x1m...
                     dmi1.*x2m dmi2.*x2m dmi3.*x2m...
                     dmi1 *x3m dmi2 *x3m dmi3 *x3m...
                     dmi1      dmi2      dmi3];
                Alpha = Alpha + A'*A;
                Beta  = Beta  - sum(A,1)';
            end
        end

        Alpha = R'*Alpha*R;
        Beta  = R'*Beta;

        % Gauss-Newton update
        sol1  = sol - stepsize*((Alpha+Alpha0)\(Beta+Alpha0*(sol-mu)));
    end

    Affine = P2M(sol);
end


%==========================================================================
% function P = M2P(M)
%==========================================================================
% Polar decomposition parameterisation of affine transform, based on matrix logs
function P = M2P(M)
    J  = M(1:3,1:3);
    V  = sqrtm(J*J');
    R  = V\J;

    lV = logm(V);
    lR = -logm(R);
    if (sum(sum(imag(lR).^2)) > 1e-6)
        error('Rotations by pi are still a problem.');
    end
    P       = zeros(12,1);
    P(1:3)  = M(1:3,4);
    P(4:6)  = lR([2 3 6]);
    P(7:12) = lV([1 2 3 5 6 9]);
    P       = real(P);
end

%% ==========================================================================
%  function M = P2M(P)
%  ==========================================================================
% Polar decomposition parameterisation of affine transform, based on matrix logs
function M = P2M(P)
    % Translations
    D      = P(1:3);
    D      = D(:);
    % Rotation part
    ind    = [2 3 6];
    T      = zeros(3);
    T(ind) = -P(4:6);
    R      = expm(T-T');
    % Symmetric part (zooms and shears)
    ind    = [1 2 3 5 6 9];
    T      = zeros(3);
    T(ind) = P(7:12);
    V      = expm(T+T'-diag(diag(T)));
    % Result
    M      = [V*R D ; 0 0 0 1];
end


%% ==========================================================================
%  function R = derivs(MF,P,MG)
%  ==========================================================================
% Numerically compute derivatives of Affine transformation matrix w.r.t. changes in the parameters.
function R = derivs(MF,P,MG) 
    R  = zeros(12,12);
    M0 = MF\P2M(P)*MG;
    M0 = M0(1:3,:);
    for i=1:12
        dp     = 0.0000001;
        P1     = P;
        P1(i)  = P1(i) + dp;
        M1     = MF\P2M(P1)*MG;
        M1     = M1(1:3,:);
        R(:,i) = (M1(:)-M0(:))/dp;
    end
end


%% ==========================================================================
%  spm_affine_priors('mni')
%  ==========================================================================
% Distribution of the priors used in affine registration
function [mu,isig] = bst_spm_affine_priors()
    % case 'mni'
    % For registering with MNI templates...
    mu   = [0.0667 0.0039 0.0008 0.0333 0.0071 0.1071]';
    isig = 1e4 * [
        0.0902   -0.0345   -0.0106   -0.0025   -0.0005   -0.0163
       -0.0345    0.7901    0.3883    0.0041   -0.0103   -0.0116
       -0.0106    0.3883    2.2599    0.0113    0.0396   -0.0060
       -0.0025    0.0041    0.0113    0.0925    0.0471   -0.0440
       -0.0005   -0.0103    0.0396    0.0471    0.2964   -0.0062
       -0.0163   -0.0116   -0.0060   -0.0440   -0.0062    0.1144];
end


%% ==========================================================================
%  spm_sample_priors8
%  ==========================================================================
% Sample prior probability maps.
% x1,x2,x3    - coordinates to sample
% s           - sampled values
% ds1,ds2,ds3 - spatial derivatives of sampled values
%__________________________________________________________________________
% Copyright (C) 2008-2014 Wellcome Trust Centre for Neuroimaging
% John Ashburner
function [s,ds1,ds2,ds3] = bst_spm_sample_priors8(tpm,x1,x2,x3)
    deg  = tpm.deg;
    tiny = tpm.tiny;

    d  = size(tpm.dat{1});
    dx = size(x1);
    Nv = numel(tpm.dat);
    s  = cell(1,Nv);
    msk1 = x1>=1 & x1<=d(1) & x2>=1 & x2<=d(2) & x3>=1 & x3<=d(3);
    msk2 = x3<1;
    x1 = x1(msk1);
    x2 = x2(msk1);
    x3 = x3(msk1);
    if nargout<=1,
        tot = zeros(dx);
        for k=1:Nv,
            a    = spm_bsplins(tpm.dat{k},x1,x2,x3,[deg deg deg  0 0 0]);
            s{k} = ones(dx)*tpm.bg2(k);
            s{k}(msk1) = exp(a);
            s{k}(msk2) = tpm.bg1(k);
            tot  = tot + s{k};
        end
        msk      = ~isfinite(tot);
        tot(msk) = 1;
        for k=1:Nv,
            s{k}(msk) = tpm.bg2(k);
            s{k}      = s{k}./tot;
        end
    else
        ds1 = cell(1,Nv);
        ds2 = cell(1,Nv);
        ds3 = cell(1,Nv);
        tot = zeros(dx);
        for k=1:Nv,
            [a,da1,da2,da3] = spm_bsplins(tpm.dat{k},x1,x2,x3,[deg deg deg  0 0 0]);
            if k==Nv, s{k} = ones(dx); else s{k} = zeros(dx)+tiny; end
            s{k} = ones(dx)*tpm.bg2(k);
            s{k}(msk1) = exp(a);
            s{k}(msk2) = tpm.bg1(k);
            tot    = tot + s{k};
            ds1{k} = zeros(dx); ds1{k}(msk1) = da1;
            ds2{k} = zeros(dx); ds2{k}(msk1) = da2;
            ds3{k} = zeros(dx); ds3{k}(msk1) = da3;
        end
        msk      = find(~isfinite(tot));
        tot(msk) = 1;
        da1      = zeros(dx);
        da2      = zeros(dx);
        da3      = zeros(dx);
        for k=1:Nv,
             s{k}(msk) = tpm.bg1(k);
             s{k}      = s{k}./tot;
             da1       = da1 + s{k}.*ds1{k};
             da2       = da2 + s{k}.*ds2{k};
             da3       = da3 + s{k}.*ds3{k};
        end
        for k=1:Nv,
            ds1{k} = s{k}.*(ds1{k} - da1); ds1{k}(msk) = 0;
            ds2{k} = s{k}.*(ds2{k} - da2); ds2{k}(msk) = 0;
            ds3{k} = s{k}.*(ds3{k} - da3); ds3{k}(msk) = 0;
        end
    end
end


