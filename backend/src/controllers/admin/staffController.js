const { User, RefreshToken } = require('../../models');
const { USER_ROLES, AUTH_PROVIDERS } = require('../../utils/constants');
const { ConflictError, NotFoundError, BadRequestError } = require('../../utils/errors');
const { paginate, formatPaginationResponse, sanitizeUser } = require('../../utils/helpers');
const { recordAudit } = require('../../services/auditService');

exports.getStaff = async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);
    const search = String(req.query.search || '').trim();
    const query = { role: USER_ROLES.STAFF };

    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { username: { $regex: search, $options: 'i' } },
      ];
    }

    const [staff, total] = await Promise.all([
      User.find(query).select('-passwordHash').sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
      User.countDocuments(query),
    ]);

    res.json({ success: true, ...formatPaginationResponse(staff, total, page, limit) });
  } catch (error) {
    next(error);
  }
};

exports.createStaff = async (req, res, next) => {
  try {
    const { name, username, password } = req.body;
    const normalizedUsername = username.toLowerCase();
    const existing = await User.findOne({ username: normalizedUsername });
    if (existing) {
      throw new ConflictError('Username is already in use', 'STAFF_USERNAME_EXISTS');
    }

    const staff = await User.create({
      name,
      username: normalizedUsername,
      passwordHash: password,
      authProvider: AUTH_PROVIDERS.EMAIL,
      role: USER_ROLES.STAFF,
      mustChangePassword: false,
      isActive: true,
    });

    await recordAudit({
      actorId: req.user._id,
      action: 'staff.created',
      entityType: 'user',
      entityId: staff._id,
      metadata: { username: staff.username },
    });

    res.status(201).json({
      success: true,
      message: 'Member account created. Share the password securely.',
      data: sanitizeUser(staff),
    });
  } catch (error) {
    next(error);
  }
};

exports.resetStaffPassword = async (req, res, next) => {
  try {
    const staff = await User.findOne({ _id: req.params.id, role: USER_ROLES.STAFF }).select('+passwordHash');
    if (!staff) throw new NotFoundError('Member account not found', 'STAFF_NOT_FOUND');

    staff.passwordHash = req.body.password;
    staff.mustChangePassword = false;
    await staff.save();
    await RefreshToken.updateMany({ userId: staff._id }, { isRevoked: true });

    await recordAudit({
      actorId: req.user._id,
      action: 'staff.password_reset',
      entityType: 'user',
      entityId: staff._id,
    });

    res.json({ success: true, message: 'Password reset and active sessions revoked.' });
  } catch (error) {
    next(error);
  }
};

exports.updateStaffStatus = async (req, res, next) => {
  try {
    const staff = await User.findOne({ _id: req.params.id, role: USER_ROLES.STAFF });
    if (!staff) throw new NotFoundError('Member account not found', 'STAFF_NOT_FOUND');

    const { isActive } = req.body;
    if (staff.isActive === isActive) {
      throw new BadRequestError('Member account already has this status', 'STAFF_STATUS_UNCHANGED');
    }

    staff.isActive = isActive;
    await staff.save();
    if (!isActive) await RefreshToken.updateMany({ userId: staff._id }, { isRevoked: true });

    await recordAudit({
      actorId: req.user._id,
      action: isActive ? 'staff.activated' : 'staff.deactivated',
      entityType: 'user',
      entityId: staff._id,
    });

    res.json({
      success: true,
      message: `Member account ${isActive ? 'activated' : 'deactivated'}.`,
      data: sanitizeUser(staff),
    });
  } catch (error) {
    next(error);
  }
};
