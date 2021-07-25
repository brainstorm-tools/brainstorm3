function R = YuleWalker_Inverse(A,Sigma, maxOrder)
%YULEWALKER Summary of this function goes here
%   A partire dalla matrice A e dalle correlazioni dei residui ottengo le
%   correlazioni a vari ritardi. Le Gamma sono matrici N x N e in totale
%   saranno (P+1)
%   L'approccio dovrebbe essere di trasformare il problema in un'equazione
%   di Lyapunov

    [N,~] = size(Sigma);
    p = size(A,2)/N;
    
    % Copiato da CElinVAR
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

