function [ prod ] = quatmult( q,r )
    t0 = r(1)*q(1) - r(2)*q(2) - r(3)*q(3) - r(4)*q(4);
    t1 = r(1)*q(2) + r(2)*q(1) - r(3)*q(4) + r(4)*q(3);
    t2 = r(1)*q(3) + r(2)*q(4) + r(3)*q(1) - r(4)*q(2);
    t3 = r(1)*q(4) - r(2)*q(3) + r(3)*q(2) + r(4)*q(1);
    
    prod = [t0; t1; t2; t3];