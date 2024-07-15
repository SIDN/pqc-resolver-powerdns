# Copyright (c) 2024 SIDN Labs
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

DIRECTORY=$(pwd)

mkdir -p ${DIRECTORY}/sqisign-compile
echo '#ifndef sqisign1_h' | tee ${DIRECTORY}/sqisign-compile/sqisign1.h
echo '#define sqisign1_h' | tee -a ${DIRECTORY}/sqisign-compile/sqisign1.h
echo | tee -a ${DIRECTORY}/sqisign-compile/sqisign1.h
grep CRYPTO ${DIRECTORY}/sqisign/src/nistapi/lvl1/api.h | tee -a ${DIRECTORY}/sqisign-compile/sqisign1.h
sed -i -e 's/CRYPTO/SQISIGN1/g' ${DIRECTORY}/sqisign-compile/sqisign1.h
echo | tee -a ${DIRECTORY}/sqisign-compile/sqisign1.h
grep -E -v 'SQISIGN_H|endif' ${DIRECTORY}/sqisign/include/sig.h | tee -a ${DIRECTORY}/sqisign-compile/sqisign1.h
echo '#endif /* sqisign1_h */' | tee -a ${DIRECTORY}/sqisign-compile/sqisign1.h
# We make /usr/include/patad-testbed, used for compilation only (referred in our pdns edits)
mkdir -p /usr/include/patad-testbed && \
    cp ${DIRECTORY}/sqisign-compile/sqisign1.h /usr/include/patad-testbed/sqisign1.h

mkdir -p ${DIRECTORY}/sqisign/build
cd ${DIRECTORY}/sqisign/build && cmake -DSQISIGN_BUILD_TYPE=ref .. && make sqisign_lvl1 -j $(nproc)
cd ${DIRECTORY}/sqisign/build && \
    cp src/libsqisign_lvl1.a \
    src/klpt/ref/lvl1/libsqisign_klpt_lvl1.a \
    src/intbig/ref/generic/libsqisign_intbig_generic.a \
    src/id2iso/ref/lvl1/libsqisign_id2iso_lvl1.a \
    src/quaternion/ref/generic/libsqisign_quaternion_generic.a \
    src/gf/ref/lvl1/libsqisign_gf_lvl1.a \
    src/protocols/ref/lvl1/libsqisign_protocols_lvl1.a \
    src/ec/ref/lvl1/libsqisign_ec_lvl1.a \
    src/precomp/ref/lvl1/libsqisign_precomp_lvl1.a \
    src/common/generic/libsqisign_common_sys.a \
    /usr/lib