function C = cmap_dory(N)
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
% Authors: Rana El Khoury, 2019

cmap =  [
            0.25326781 0.00147115 0.07897669  
            0.255698   0.00590956 0.08587843  
            0.25812296 0.01048378 0.09261068  
            0.26048714 0.01527654 0.0993234   
            0.2627889  0.02029377 0.10602441  
            0.26502429 0.02554474 0.1127261   
            0.26719833 0.03102568 0.11941909  
            0.26931097 0.03673999 0.126106    
            0.27136511 0.04261464 0.13278268  
            0.27336127 0.04827311 0.13945039  
            0.27529754 0.0537252  0.14611558  
            0.27718507 0.05899332 0.15275664  
            0.27901516 0.06411607 0.15939478  
            0.28079823 0.06910408 0.16601079  
            0.28253586 0.07397437 0.17260466  
            0.28422138 0.07874838 0.17919283  
            0.28586628 0.0834275  0.18575557  
            0.28747161 0.08802173 0.19229453  
            0.28903846 0.09253935 0.19881149  
            0.29056969 0.0969859  0.20530501  
            0.29206219 0.10137056 0.21178505  
            0.2935244  0.10569269 0.2182403   
            0.29495723 0.109957   0.22467382  
            0.29636301 0.11416648 0.23108628  
            0.29774414 0.11832368 0.23747849  
            0.29910296 0.12243075 0.24385159  
            0.30044175 0.12648955 0.25020698  
            0.30176274 0.1305017  0.25654635  
            0.30306844 0.13446839 0.26287105  
            0.30435742 0.13839279 0.26918938  
            0.30563314 0.14227504 0.27550115  
            0.30689822 0.1461156  0.28180766  
            0.30815526 0.14991493 0.28811028  
            0.30940586 0.15367384 0.29441197  
            0.31065045 0.1573936  0.30071771  
            0.31189147 0.1610744  0.30702871  
            0.31312425 0.16471949 0.31335878  
            0.31435267 0.16832812 0.3197063   
            0.3155793  0.17190019 0.32607159  
            0.31680536 0.17543619 0.33245706  
            0.31803076 0.17893707 0.33886721  
            0.31924741 0.18240644 0.34532162  
            0.32046304 0.18584215 0.35180955  
            0.32167852 0.18924467 0.35833269  
            0.32288992 0.1926159  0.36490186  
            0.32408137 0.19598151 0.37145084  
            0.32524407 0.19933798 0.37802942  
            0.32637561 0.20268693 0.38463929  
            0.3274746  0.20602981 0.39127907  
            0.32853653 0.20937557 0.3979208   
            0.32956116 0.21271844 0.40459357  
            0.33054588 0.21606016 0.41129727  
            0.33148748 0.21940267 0.41803225  
            0.33238362 0.22274897 0.42479056  
            0.3332301  0.22610463 0.43155707  
            0.33402452 0.22946666 0.43835189  
            0.33476462 0.23283688 0.44517129  
            0.33544597 0.23621762 0.45201482  
            0.33606551 0.23961095 0.45887889  
            0.33661957 0.2430191  0.46576034  
            0.33710394 0.24644575 0.47265016  
            0.33751391 0.24989427 0.47954141  
            0.33784636 0.25336435 0.48644008  
            0.33809692 0.25685846 0.49334157  
            0.33826098 0.26037916 0.50024083  
            0.338334   0.26392904 0.50713208  
            0.33831135 0.26751069 0.51400891  
            0.33818823 0.27112674 0.5208645   
            0.33795975 0.27477987 0.52769145  
            0.33762027 0.27847289 0.53448259  
            0.33716513 0.28220837 0.54122889  
            0.33658972 0.28598881 0.5479208   
            0.33588899 0.28981675 0.55454869  
            0.33505701 0.29369491 0.56110334  
            0.33409085 0.2976251  0.56757218  
            0.33298446 0.30161396 0.57392565  
            0.33173578 0.30566002 0.58016348  
            0.33033944 0.30976467 0.58627799  
            0.32879412 0.31392864 0.59225547  
            0.32709741 0.31815276 0.59808344  
            0.3252471  0.3224376  0.60374977  
            0.32324513 0.32678802 0.60921242  
            0.32109236 0.33120054 0.61447223  
            0.3187902  0.33567128 0.61953097  
            0.31634222 0.34019813 0.62437812  
            0.31375452 0.34478125 0.62898749  
            0.31103562 0.34942012 0.63333244  
            0.30819072 0.3541049  0.63744059  
            0.30522859 0.35883116 0.64130748  
            0.30216187 0.36359742 0.64490833  
            0.29900337 0.36839956 0.64823364  
            0.29576096 0.37322734 0.65131606  
            0.29244642 0.37807539 0.65415882  
            0.28907537 0.38294095 0.65674735  
            0.28566226 0.38781956 0.65908034  
            0.28221384 0.39270226 0.6611951   
            0.27874194 0.39758428 0.66310081  
            0.27525648 0.40246162 0.66480721  
            0.271773   0.40733295 0.66630287  
            0.26829955 0.4121931  0.66761053  
            0.26484029 0.41703779 0.66875502  
            0.26140162 0.4218648  0.66974739  
            0.25799151 0.4266716  0.67059946  
            0.25461321 0.43145715 0.67132154  
            0.25127244 0.43621981 0.67192484  
            0.24796035 0.44096195 0.67241482  
            0.24477119 0.44567064 0.67276498  
            0.24174579 0.45034614 0.67294065  
            0.23891264 0.45498565 0.67294375  
            0.23630465 0.45958644 0.67277269  
            0.2339661  0.46414408 0.67242554  
            0.23194028 0.46865471 0.67190032  
            0.23027412 0.4731135  0.67119884  
            0.22901175 0.47751615 0.67032358  
            0.22826129 0.48185135 0.66925311  
            0.22801165 0.4861201  0.6680156   
            0.22828199 0.49031996 0.66662485  
            0.22909505 0.4944477  0.66509199  
            0.23046482 0.49850065 0.66342989  
            0.23247544 0.50246811 0.6616239   
            0.23504533 0.50635693 0.65971682  
            0.23815249 0.51016739 0.65772636  
            0.24177297 0.51389973 0.65566889  
            0.2458763  0.51755504 0.65355928  
            0.25046517 0.52113053 0.65139828  
            0.25548021 0.52463043 0.64920847  
            0.26085582 0.52806056 0.64701     
            0.26655059 0.53142392 0.64481605  
            0.27252528 0.53472393 0.64263561  
            0.27874056 0.53796407 0.64048032  
            0.28516166 0.54114804 0.63835621  
            0.29175523 0.54427954 0.63627073  
            0.2984896  0.54736226 0.63423204  
            0.30533823 0.55039991 0.6322437   
            0.31227626 0.55339608 0.63031033  
            0.31928122 0.55635432 0.62843615  
            0.32633365 0.55927804 0.62662402  
            0.33341614 0.56217055 0.62487655  
            0.3405138  0.56503502 0.62319529  
            0.34761349 0.5678745  0.62158153  
            0.35470219 0.57069201 0.62003802  
            0.36176989 0.57349039 0.61856526  
            0.36880933 0.57627218 0.61716183  
            0.3758413  0.57903459 0.6158166   
            0.38284084 0.58178312 0.61453783  
            0.38979359 0.58452189 0.61332677  
            0.39669173 0.58725351 0.61218591  
            0.4035346  0.58997973 0.61111008  
            0.41033333 0.5926992  0.61009523  
            0.41709961 0.59541097 0.60913071  
            0.42379824 0.59812337 0.60823001  
            0.43042741 0.60083824 0.60739065  
            0.43700091 0.60355401 0.60660307  
            0.44354012 0.60626702 0.60585615  
            0.45000427 0.60898753 0.60516387  
            0.45639398 0.61171691 0.60452146  
            0.4627487  0.61444735 0.60390846  
            0.46904131 0.61718615 0.60333395  
            0.47525734 0.61993812 0.60279912  
            0.48142579 0.62269761 0.60228748  
            0.48754603 0.62546596 0.60179403  
            0.49359125 0.62825095 0.60132584  
            0.49959335 0.63104592 0.60086412  
            0.5055496  0.63385274 0.60040381  
            0.51143533 0.63667873 0.59995161  
            0.51729728 0.63951328 0.59947913  
            0.52310873 0.64236417 0.59899384  
            0.5288662  0.64523346 0.59849109  
            0.53461934 0.64810924 0.5979407   
            0.54032233 0.65100431 0.59735988  
            0.54601294 0.65390966 0.59672369  
            0.55169024 0.65682613 0.59602841  
            0.55734334 0.65975727 0.59527523  
            0.56302387 0.66268984 0.59443131  
            0.56869055 0.66563514 0.59351696  
            0.57439265 0.66858018 0.59250125  
            0.58011278 0.6715296  0.5913935   
            0.58587886 0.67447678 0.5901642   
            0.59165326 0.67743331 0.58881962  
            0.59746799 0.68039119 0.58732893  
            0.60329842 0.6833553  0.58572702  
            0.60919121 0.68631385 0.58396707  
            0.61512228 0.68927143 0.58208488  
            0.62111658 0.69222115 0.58005785  
            0.62717853 0.69516082 0.57788814  
            0.63329284 0.69809318 0.57559954  
            0.63949162 0.7010094  0.57315906  
            0.64574846 0.70391511 0.57060254  
            0.65207932 0.70680545 0.56791491  
            0.65849613 0.70967668 0.56508262  
            0.6649583  0.71253835 0.56215905  
            0.67150453 0.71538003 0.55909598  
            0.67812331 0.71820405 0.55590777  
            0.68478925 0.72101664 0.55262614  
            0.6915319  0.72380963 0.54921156  
            0.69833733 0.72658626 0.54568055  
            0.70518258 0.72935266 0.54205885  
            0.71209373 0.7321014  0.53831091  
            0.71906681 0.73483327 0.53443856  
            0.72606366 0.73755923 0.53048431  
            0.7331152  0.74027021 0.52640717  
            0.74021851 0.74296694 0.52220577  
            0.74735736 0.74565423 0.51789572  
            0.75452081 0.74833548 0.51348593  
            0.76172532 0.75100574 0.50895081  
            0.76896886 0.75366577 0.50428579  
            0.77624333 0.75631804 0.49949677  
            0.78352306 0.75897093 0.49461086  
            0.79083133 0.76161737 0.48959029  
            0.7981638  0.76425892 0.48443404  
            0.80551486 0.76689755 0.47914364  
            0.81288466 0.76953378 0.47370651  
            0.82026577 0.7721702  0.46812717  
            0.8276388  0.77481381 0.46242323  
            0.8350164  0.77746089 0.45656702  
            0.84239494 0.78011323 0.45055229  
            0.84977061 0.78277279 0.44437123  
            0.85713743 0.78544225 0.43802014  
            0.86448995 0.78812428 0.43149255  
            0.87182216 0.79082182 0.42478158  
            0.87912751 0.79353811 0.41787986  
            0.88639967 0.79627651 0.41077679  
            0.89363261 0.79904044 0.40345751  
            0.90080088 0.80184052 0.39593899  
            0.90789918 0.80468031 0.38820113  
            0.91492539 0.80756232 0.38021452  
            0.92186711 0.81049289 0.37196502  
            0.92869413 0.81348558 0.36346074  
            0.93536868 0.81655739 0.35471628  
            0.94190586 0.81970493 0.34565564  
            0.94821891 0.82296487 0.33636782  
            0.95432552 0.82633317 0.32676075  
            0.9601093  0.82985912 0.31696804  
            0.96556258 0.83354875 0.30694106  
            0.97060289 0.83743781 0.29676469  
            0.9751387  0.84156454 0.28657841  
            0.97907634 0.84596667 0.27656766  
            0.982329   0.85067645 0.26698503  
            0.98483171 0.8557138  0.25814006  
            0.98655719 0.86107992 0.25036826  
            0.98752325 0.86675567 0.24397026  
            0.98809505 0.87259331 0.23815957  
            0.9886395  0.87844815 0.23205879  
            0.98915956 0.88431854 0.2256528   
            0.9896515  0.8902064  0.21890348  
            0.99011241 0.89611314 0.211769    
            0.99054458 0.90203747 0.20421664  
            0.99094616 0.90798023 0.1961925   
            0.99131383 0.91394299 0.18762556  
            0.99164546 0.91992667 0.1784317   
            0.99194474 0.92592926 0.16852643  
            0.99220328 0.93195477 0.15774692  
            0.99242196 0.93800254 0.14591519  
            0.99259264 0.94407632 0.13273228  
            0.99271173 0.95017753 0.11777307  
            0.99268038 0.95635316 0.09972605 ] ;

P = size(cmap, 1);

if nargin < 1
   N = P;
end

N = min(N, P);
C = interp1(1:P  ,cmap , linspace(1, P, N) , 'linear');
