function R = yule_walker_inverse(A,Sigma, maxOrder)
% YULE_WALKER_INVErSE   Solve the inverse Yule-Walker system of equations.
%                       Given the couplings A and the covariance matrix
%                       Sigma it evaluated the correlations of the time
%                       series up to an arbitrary order
%
% Inputs:
%   A                 - Couplings of the VAR model 
%                       [N x Np, where Np = N x p]
%   Sigma             - Residuals covariance matrix
%                       [N x N]
%   maxOrder          - Maximum order for the data correlations
%
% Outputs:
%   R                 - Correlations of the time series obtained using the
%                       Yule-Walker equations
%                       [N x N x (maxOrder+1)]

    [N,~] = size(Sigma);
    p = size(A,2)/N;
    
    Im = eye(N*p);
    F = [A; Im(1:end-N,:)];
    Delta=zeros(N*p); 
    Delta(1:N,1:N) = Sigma;
    BigSigma = dlyap(F,Delta);

    R=NaN*ones(N,N,maxOrder+1); 
    for i=1:p
        R(:,:,i)=BigSigma(1:N,N*(i-1)+1:N*i);
    end
    
    for k=p+1:maxOrder+1
        Rk=R(:,:,k-1:-1:k-p);
        Rm=[];
        for ki=1:p
            Rm=[Rm; Rk(:,:,ki)];
        end
        R(:,:,k)=A*Rm;
    end
        
end

