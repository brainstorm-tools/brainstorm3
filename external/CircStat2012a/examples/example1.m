% Philipp Berens
% CircStat: A Matlab Toolbox for Circular Statistics
% Submitted to Journal of Statistical Software
%
% Example 1
%
% Demonstrate functionality of all functions of the CircStat toolbox using
% artifical data.

%% part1: generate data

alpha_deg = [13 15 21 26 28 30 35 36 41 60 92 103 165 199 210 ...
        250 301 320 343 359]';

alpha_rad = circ_ang2rad(alpha_deg);       % convert to radians

beta_deg = [1 13 41 56 67 71 81 85 99 110 119 131 145 177 199 220 ...
      291 320 340 355]';
beta_rad = circ_ang2rad(beta_deg);         % convert to radians

fprintf('\nTHE CIRCSTAT TOOLBOX EXAMPLE\n\nDescriptive Statistics\n')

%% part2: plot data (generate figure 1)

figure(1)
subplot(2,2,1)
circ_plot(alpha_rad,'pretty','bo',true,'linewidth',2,'color','r'),

subplot(2,2,3)
circ_plot(alpha_rad,'hist',[],20,true,true,'linewidth',2,'color','r')

subplot(2,2,2)
circ_plot(beta_rad,'pretty','bo',true,'linewidth',2,'color','r'),

subplot(2,2,4)
circ_plot(beta_rad,'hist',[],20,true,true,'linewidth',2,'color','r')

%% part 3: descriptive statistics

fprintf('\t\t\t\t\t\tALPHA\tBETA\n')

alpha_bar = circ_mean(alpha_rad);
beta_bar = circ_mean(beta_rad);

fprintf('Mean resultant vector:\t%.2f \t%.2f\n', circ_rad2ang([alpha_bar beta_bar]))

alpha_hat = circ_median(alpha_rad);
beta_hat = circ_median(beta_rad);

fprintf('Median:\t\t\t\t\t%.2f \t%.2f\n', circ_rad2ang([alpha_hat beta_hat]))

R_alpha = circ_r(alpha_rad);
R_beta = circ_r(beta_rad);

fprintf('R Length:\t\t\t\t\t%.2f \t%.2f\n',[R_alpha R_beta])

S_alpha = circ_var(alpha_rad);
S_beta = circ_var(beta_rad);

fprintf('Variance:\t\t\t\t%.2f \t%.2f\n',[S_alpha S_beta])

[s_alpha s0_alpha] = circ_std(alpha_rad);
[s_beta s0_beta] = circ_std(beta_rad);

fprintf('Standard deviation:\t\t%.2f \t%.2f\n',[s_alpha s_beta])
fprintf('Standard deviation 0:\t%.2f \t%.2f\n',[s0_alpha s0_beta])

b_alpha = circ_skewness(alpha_rad);
b_beta = circ_skewness(beta_rad);

fprintf('Skewness:\t\t\t\t%.2f \t%.2f\n',[b_alpha b_beta])

k_alpha = circ_kurtosis(alpha_rad);
k_beta = circ_kurtosis(beta_rad);

fprintf('Kurtosis:\t\t\t\t%.2f \t%.2f\n',[k_alpha k_beta])

fprintf('\n\n')

%% part 4: inferential statistics

fprintf('Inferential Statistics\n\nTests for Uniformity\n')

% Rayleigh test
p_alpha = circ_rtest(alpha_rad);
p_beta = circ_rtest(beta_rad);
fprintf('Rayleigh Test, \t\t P = %.2f \t%.2f\n',[p_alpha p_beta])

% Omnibus test
p_alpha = circ_otest(alpha_rad);
p_beta = circ_otest(beta_rad);
fprintf('Omnibus Test, \t\t P = %.2f \t%.2f\n',[p_alpha p_beta])

% Rao's spacing test
p_alpha = circ_raotest(alpha_rad);
p_beta = circ_raotest(beta_rad);
fprintf('Rao Spacing Test, \t P = %.2f \t%.2f\n',[p_alpha p_beta])

% V test
p_alpha = circ_vtest(alpha_rad,circ_ang2rad(0));
p_beta = circ_vtest(beta_rad,circ_ang2rad(0));
fprintf('V Test (r = 0), \t P = %.2f \t%.2f\n',[p_alpha p_beta])


fprintf('\nTests concerning Mean and Median angle\n')

% 95 percent confidence intervals for mean direction
t_alpha = circ_confmean(alpha_rad,0.05);
t_beta = circ_confmean(beta_rad,0.05);

fprintf('Mean, up 95 perc. CI:\t\t\t%.2f \t%.2f\n', circ_rad2ang([alpha_bar+t_alpha beta_bar+t_beta]))
fprintf('Mean, low 95 perc. CI:\t\t\t%.2f \t%.2f\n', circ_rad2ang([2*pi+alpha_bar-t_alpha beta_bar-t_beta]))

h1 = circ_mtest(alpha_rad,0);
h2 = circ_mtest(alpha_rad,circ_ang2rad(90));

fprintf('Mean Test (alpha), mean = 0 deg:\t\t%d\n',h1)
fprintf('Mean Test (alpha), mean = 90 deg:\t\t%d\n',h2)


h1 = circ_medtest(alpha_rad,circ_ang2rad(25));
h2 = circ_medtest(alpha_rad,circ_ang2rad(105));

fprintf('Median Test (alpha), median = 25 deg:\t%.2f\n',h1)
fprintf('Median Test (alpha), median = 105 deg:\t%.2f\n',h2)

h1 = circ_symtest(alpha_rad);
h2 = circ_symtest(beta_rad);

fprintf('Symmetry around median (alpha/beta):\t\t\t%.2f\t %.2f\n',h1,h2)


%% part 4: association
fprintf('Measures of Association\n\nCircular-Circular Association\n')

figure
subplot(121)
plot(alpha_rad,beta_rad,'ok')
formatSubplot(gca,'xl','\alpha_i','yl','\beta_i', 'ax','square','box','off', 'lim',[0 2*pi 0 2*pi ])

subplot(122)
plot(1:20,alpha_rad,'or',1:20,beta_rad,'ok')
formatSubplot(gca,'xl','x','yl','\alpha_i (red) / \beta_i (black)', 'ax','square','box','off', 'lim',[0 21 0 2*pi ])


% compute circular - circular correlation of alpha and beta
[c p] = circ_corrcc(alpha_rad,beta_rad);
fprintf('Circ-circ corr coeff/pval:\t%.2f\t %.3f\n',c,p)


% cmpute circular - linear correlation of alpha/beta with 1:20
[ca pa] = circ_corrcl(alpha_rad,1:20);
[cb pb] = circ_corrcl(beta_rad,1:20);

fprintf('Circ-lin corr coeff:\t\t%.2f\t %.2f\n',ca,cb)
fprintf('Circ-lin corr pval:\t\t\t%.3f\t %.3f\n',pa,pb)


%% part 5: multi-sample tests
% the dataset we use here consists of three samples from von mises
% distributions with common parameter kappa = 10 and means equal to pi,
% pi+.25 and pi+.5.

load data

fprintf('\nMulti-Sample tests\n')

fprintf('\nTEST 1: ONE FACTOR ANOVA, theta1 vs theta2\n')
p = circ_wwtest(theta1,theta2);

fprintf('\nTEST 2: ONE FACTOR ANOVA, theta1 vs theta2 vs theta3\n')
p = circ_wwtest(theta,idx);


p = circ_cmtest(theta1,theta2);
fprintf('TEST 3: NON PARAMETRIC ONE FACTOR ANOVA, theta1 vs. theta2\nP = %.4f\n\n',p)

fprintf('\nTEST 4: TWO FACTOR ANOVA, theta1 vs theta2\n')

idp = idx(1:60);    % factor 1: two original groups
idq = idp(randperm(length(idp))); % factor 2: random assignment to groups

p = circ_hktest([theta1; theta2], idp,idq,true);












